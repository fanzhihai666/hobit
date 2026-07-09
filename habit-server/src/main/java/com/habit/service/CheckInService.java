package com.habit.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.habit.entity.CheckInRecord;
import com.habit.entity.Habit;
import com.habit.mapper.CheckInRecordMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
public class CheckInService extends ServiceImpl<CheckInRecordMapper, CheckInRecord> {

    private final String imageBaseUrl;
    private final HabitService habitService;

    @Autowired
    public CheckInService(@Qualifier("imageBaseUrl") String imageBaseUrl, HabitService habitService) {
        this.imageBaseUrl = imageBaseUrl;
        this.habitService = habitService;
    }

    /**
     * 打卡（支持每日打卡和一次性打卡）
     */
    @Transactional
    public boolean checkIn(CheckInRecord record) {
        Habit habit = habitService.getById(record.getHabitId());
        if (habit == null) {
            throw new RuntimeException("习惯不存在");
        }

        // 一次性打卡：如果已完成，不允许重复打卡
        if (habit.getCheckInType() != null && habit.getCheckInType() == 2) {
            if (habit.getIsCompleted() != null && habit.getIsCompleted() == 1) {
                throw new RuntimeException("该习惯已完成，无需重复打卡");
            }
            // 标记为最终完成
            record.setIsFinal(1);
            // 更新习惯完成状态
            habit.setIsCompleted(1);
            habitService.updateById(habit);
        } else {
            // 每日打卡：检查今日是否已打卡
            if (hasCheckedIn(record.getHabitId(), record.getCheckInDate())) {
                throw new RuntimeException("今日已打卡");
            }
            record.setIsFinal(0);
        }

        record.setCheckInTime(LocalDateTime.now());
        return save(record);
    }

    /**
     * 获取今日打卡记录
     */
    public List<CheckInRecord> getTodayRecords(Long userId, String date) {
        LambdaQueryWrapper<CheckInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(CheckInRecord::getUserId, userId)
                .eq(CheckInRecord::getCheckInDate, date);
        List<CheckInRecord> records = list(wrapper);

        // 补充一次性打卡的历史完成记录
        LambdaQueryWrapper<CheckInRecord> finalWrapper = new LambdaQueryWrapper<>();
        finalWrapper.eq(CheckInRecord::getUserId, userId)
                .eq(CheckInRecord::getIsFinal, 1);
        List<CheckInRecord> finalRecords = list(finalWrapper);

        Set<Long> habitIds = new HashSet<>();
        for (CheckInRecord r : records) {
            habitIds.add(r.getHabitId());
            if (r.getImageUrl() != null && !r.getImageUrl().isEmpty()) {
                r.setFullImageUrl(imageBaseUrl + r.getImageUrl());
            }
        }
        for (CheckInRecord r : finalRecords) {
            if (!habitIds.contains(r.getHabitId())) {
                records.add(r);
                habitIds.add(r.getHabitId());
            }
        }

        return records;
    }

    /**
     * 获取用户习惯的今日打卡状态
     */
    public Map<Long, Boolean> getTodayCheckInStatus(Long userId, String date) {
        Map<Long, Boolean> statusMap = new HashMap<>();

        List<Habit> habits = habitService.getUserHabits(userId);

        for (Habit habit : habits) {
            if (habit.getCheckInType() != null && habit.getCheckInType() == 2) {
                // 一次性打卡：看is_completed
                statusMap.put(habit.getId(), habit.getIsCompleted() != null && habit.getIsCompleted() == 1);
            } else {
                // 每日打卡：查今日记录
                boolean checked = hasCheckedIn(habit.getId(), date);
                statusMap.put(habit.getId(), checked);
            }
        }

        return statusMap;
    }

    /**
     * 检查某日是否已打卡
     */
    public boolean hasCheckedIn(Long habitId, String date) {
        return lambdaQuery()
                .eq(CheckInRecord::getHabitId, habitId)
                .eq(CheckInRecord::getCheckInDate, date)
                .count() > 0;
    }

    /**
     * 重置一次性打卡状态
     */
    @Transactional
    public boolean resetHabit(Long habitId) {
        Habit habit = habitService.getById(habitId);
        if (habit == null) {
            return false;
        }
        habit.setIsCompleted(0);
        habitService.updateById(habit);

        lambdaUpdate()
                .eq(CheckInRecord::getHabitId, habitId)
                .eq(CheckInRecord::getIsFinal, 1)
                .remove();

        return true;
    }

    /**
     * 统计信息
     */
    public Map<String, Object> getStatistics(Long userId) {
        Map<String, Object> result = new HashMap<>();

        int continuousDays = calcContinuousDays(userId);
        result.put("continuousDays", continuousDays);

        List<Map<String, Object>> weekData = new ArrayList<>();
        LocalDate today = LocalDate.now();
        for (int i = 6; i >= 0; i--) {
            LocalDate date = today.minusDays(i);
            String dateStr = date.format(DateTimeFormatter.ofPattern("MM-dd"));

            Long count = Long.valueOf(lambdaQuery()
                    .eq(CheckInRecord::getUserId, userId)
                    .eq(CheckInRecord::getCheckInDate, date.toString())
                    .eq(CheckInRecord::getIsFinal, 0)
                    .count());

            Map<String, Object> item = new HashMap<>();
            item.put("date", dateStr);
            item.put("count", count);
            weekData.add(item);
        }
        result.put("weekData", weekData);

        List<String> badges = new ArrayList<>();
        if (continuousDays >= 1) badges.add("初次打卡");
        if (continuousDays >= 7) badges.add("7天坚持");
        if (continuousDays >= 21) badges.add("21天养成");
        if (continuousDays >= 100) badges.add("百日习惯");

        Long completedOnce = habitService.lambdaQuery()
                .eq(Habit::getUserId, userId)
                .eq(Habit::getCheckInType, 2)
                .eq(Habit::getIsCompleted, 1)
                .count();
        if (completedOnce >= 1) badges.add("目标达成");
        if (completedOnce >= 5) badges.add("多面手");

        result.put("badges", badges);

        return result;
    }

    /**
     * 月统计 - 修复活跃天数null问题
     */
    public Map<String, Object> getMonthStatistics(Long userId, String yearMonth) {
        Map<String, Object> result = new HashMap<>();

        String[] parts = yearMonth.split("-");
        int year = Integer.parseInt(parts[0]);
        int month = Integer.parseInt(parts[1]);

        LocalDate startOfMonth = LocalDate.of(year, month, 1);
        LocalDate endOfMonth = startOfMonth.withDayOfMonth(startOfMonth.lengthOfMonth());

        // 获取当月每天的打卡数（仅每日打卡）
        List<Map<String, Object>> monthData = new ArrayList<>();
        LocalDate current = startOfMonth;
        while (!current.isAfter(endOfMonth)) {
            String dateStr = current.toString();
            String displayDate = current.format(DateTimeFormatter.ofPattern("MM-dd"));

            Long count = Long.valueOf(lambdaQuery()
                    .eq(CheckInRecord::getUserId, userId)
                    .eq(CheckInRecord::getCheckInDate, dateStr)
                    .eq(CheckInRecord::getIsFinal, 0)
                    .count());

            Map<String, Object> item = new HashMap<>();
            item.put("date", displayDate);
            item.put("fullDate", dateStr);
            item.put("count", count);
            item.put("dayOfWeek", current.getDayOfWeek().getValue());
            monthData.add(item);
            current = current.plusDays(1);
        }
        result.put("monthData", monthData);

        // 当月总打卡次数
        Long totalCount = lambdaQuery()
                .eq(CheckInRecord::getUserId, userId)
                .ge(CheckInRecord::getCheckInDate, startOfMonth.toString())
                .le(CheckInRecord::getCheckInDate, endOfMonth.toString())
                .eq(CheckInRecord::getIsFinal, 0)
                .count();
        result.put("totalCount", totalCount != null ? totalCount : 0);

        // 活跃天数 - 修复：使用list + stream去重计算，避免null
        List<CheckInRecord> monthRecords = lambdaQuery()
                .eq(CheckInRecord::getUserId, userId)
                .ge(CheckInRecord::getCheckInDate, startOfMonth.toString())
                .le(CheckInRecord::getCheckInDate, endOfMonth.toString())
                .eq(CheckInRecord::getIsFinal, 0)
                .list();

        long activeDays = monthRecords.stream()
                .map(CheckInRecord::getCheckInDate)
                .filter(Objects::nonNull)
                .distinct()
                .count();
        result.put("activeDays", (int) activeDays);

        // 习惯完成率
        List<Habit> dailyHabits = habitService.lambdaQuery()
                .eq(Habit::getUserId, userId)
                .eq(Habit::getCheckInType, 1)
                .list();
        int habitCount = dailyHabits.size();
        int daysInMonth = startOfMonth.lengthOfMonth();
        int expectedTotal = habitCount * daysInMonth;
        double completionRate = expectedTotal > 0 ? (double) totalCount / expectedTotal * 100 : 0;
        result.put("completionRate", String.format("%.1f", completionRate));

        return result;
    }

    /**
     * 计算连续打卡天数
     */
    private int calcContinuousDays(Long userId) {
        List<Habit> dailyHabits = habitService.lambdaQuery()
                .eq(Habit::getUserId, userId)
                .eq(Habit::getCheckInType, 1)
                .list();

        if (dailyHabits.isEmpty()) {
            return 0;
        }

        Set<Long> dailyHabitIds = new HashSet<>();
        for (Habit h : dailyHabits) {
            dailyHabitIds.add(h.getId());
        }

        List<String> dates = lambdaQuery()
                .select(CheckInRecord::getCheckInDate)
                .eq(CheckInRecord::getUserId, userId)
                .eq(CheckInRecord::getIsFinal, 0)
                .in(CheckInRecord::getHabitId, dailyHabitIds)
                .groupBy(CheckInRecord::getCheckInDate)
                .orderByDesc(CheckInRecord::getCheckInDate)
                .list()
                .stream()
                .map(CheckInRecord::getCheckInDate)
                .filter(Objects::nonNull)
                .toList();

        Set<String> dateSet = new HashSet<>(dates);
        int count = 0;
        LocalDate current = LocalDate.now();

        if (!dateSet.contains(current.toString())) {
            current = current.minusDays(1);
        }

        while (dateSet.contains(current.toString())) {
            count++;
            current = current.minusDays(1);
        }
        return count;
    }

    /**
     * 撤销今日打卡（用于每日打卡）
     */
    @Transactional
    public boolean undoCheckIn(Long habitId, String date) {
        // 删除今日打卡记录
        return lambdaUpdate()
                .eq(CheckInRecord::getHabitId, habitId)
                .eq(CheckInRecord::getCheckInDate, date)
                .eq(CheckInRecord::getIsFinal, 0)
                .remove();
    }

    /**
     * 获取打卡日志列表
     */
    public List<CheckInRecord> getCheckInLogs(Long userId, String startDate, String endDate, Long habitId) {
        LambdaQueryWrapper<CheckInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(CheckInRecord::getUserId, userId)
                .orderByDesc(CheckInRecord::getCheckInDate)
                .orderByDesc(CheckInRecord::getCheckInTime);

        if (startDate != null && !startDate.isEmpty()) {
            wrapper.ge(CheckInRecord::getCheckInDate, startDate);
        }
        if (endDate != null && !endDate.isEmpty()) {
            wrapper.le(CheckInRecord::getCheckInDate, endDate);
        }
        if (habitId != null) {
            wrapper.eq(CheckInRecord::getHabitId, habitId);
        }

        List<CheckInRecord> records = list(wrapper);

        // 补充完整图片URL和习惯名称
        for (CheckInRecord record : records) {
            if (record.getImageUrl() != null && !record.getImageUrl().isEmpty()) {
                record.setFullImageUrl(imageBaseUrl + record.getImageUrl());
            }
            // 查询习惯名称
            Habit habit = habitService.getById(record.getHabitId());
            if (habit != null) {
                record.setHabitName(habit.getName());
                record.setHabitIcon(habit.getIcon());
            }
        }

        return records;
    }

    /**
     * 获取单条打卡详情
     */
    public CheckInRecord getCheckInDetail(Long id, Long userId) {
        CheckInRecord record = getById(id);
        if (record == null || !record.getUserId().equals(userId)) {
            throw new RuntimeException("记录不存在或无权限");
        }

        if (record.getImageUrl() != null && !record.getImageUrl().isEmpty()) {
            record.setFullImageUrl(imageBaseUrl + record.getImageUrl());
        }

        Habit habit = habitService.getById(record.getHabitId());
        if (habit != null) {
            record.setHabitName(habit.getName());
            record.setHabitIcon(habit.getIcon());
        }

        return record;
    }

    /**
     * 卡片专用：检查今日是否已打卡
     */
    public boolean isCheckedInToday(Long userId, Long habitId, String date) {
        return lambdaQuery()
                .eq(CheckInRecord::getUserId, userId)
                .eq(CheckInRecord::getHabitId, habitId)
                .eq(CheckInRecord::getCheckInDate, date)
                .count() > 0;
    }

    /**
     * 卡片专用：获取打卡状态
     */
    public Map<Long, Boolean> getCheckInStatus(Long userId, String date) {
        Map<Long, Boolean> statusMap = new HashMap<>();
        List<Habit> habits = habitService.listByUserId(userId);

        for (Habit habit : habits) {
            if (habit.getCheckInType() != null && habit.getCheckInType() == 2) {
                statusMap.put(habit.getId(),
                        habit.getIsCompleted() != null && habit.getIsCompleted() == 1);
            } else {
                boolean checked = lambdaQuery()
                        .eq(CheckInRecord::getHabitId, habit.getId())
                        .eq(CheckInRecord::getCheckInDate, date)
                        .count() > 0;
                statusMap.put(habit.getId(), checked);
            }
        }
        return statusMap;
    }

    /**
     * 卡片专用：快捷打卡
     */
    @Transactional
    public boolean quickCheckIn(CheckInRecord record) {
        Habit habit = habitService.getById(record.getHabitId());
        if (habit == null) {
            throw new RuntimeException("习惯不存在");
        }
        if (habit.getCheckInType() != null && habit.getCheckInType() == 2) {
            if (habit.getIsCompleted() != null && habit.getIsCompleted() == 1) {
                throw new RuntimeException("该习惯已完成");
            }
            record.setIsFinal(1);
            habit.setIsCompleted(1);
            habitService.updateById(habit);
        } else {
            if (hasCheckedIn(habit.getId(), record.getCheckInDate())) {
                throw new RuntimeException("今日已打卡");
            }
            record.setIsFinal(0);
        }
        record.setCheckInTime(LocalDateTime.now());
        return save(record);
    }
}
