package com.habit.controller;

import com.habit.common.Result;
import com.habit.entity.CheckInRecord;
import com.habit.entity.Habit;
import com.habit.service.CheckInService;
import com.habit.service.HabitService;
import com.habit.vo.CardDataVO;
import com.habit.vo.CardHabitItemVO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/checkin")
public class CheckInController {
    @Autowired
    private CheckInService checkInService;
    @Autowired
    private HabitService habitService;

    @PostMapping("/add")
    public Result<Boolean> add(@RequestBody CheckInRecord record, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        record.setUserId(userId);
        return Result.success(checkInService.checkIn(record));
    }

    @GetMapping("/today")
    public Result<List<CheckInRecord>> today(String date, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        return Result.success(checkInService.getTodayRecords(userId, date));
    }

    @GetMapping("/status")
    public Result<Map<Long, Boolean>> status(String date, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        return Result.success(checkInService.getTodayCheckInStatus(userId, date));
    }

    @GetMapping("/statistics")
    public Result<Map<String, Object>> statistics(HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        return Result.success(checkInService.getStatistics(userId));
    }

    @GetMapping("/statistics/month")
    public Result<Map<String, Object>> monthStatistics(
            @RequestParam String yearMonth,
            HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        return Result.success(checkInService.getMonthStatistics(userId, yearMonth));
    }

    @PostMapping("/reset/{habitId}")
    public Result<Boolean> reset(@PathVariable Long habitId, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        Habit habit = habitService.getById(habitId);
        if (habit == null || !habit.getUserId().equals(userId)) {
            return Result.error("习惯不存在或无权限");
        }
        return Result.success(checkInService.resetHabit(habitId));
    }

    @PostMapping("/undo/{habitId}")
    public Result<Boolean> undo(
            @PathVariable Long habitId,
            @RequestBody Map<String, String> body,
            HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        Habit habit = habitService.getById(habitId);
        if (habit == null || !habit.getUserId().equals(userId)) {
            return Result.error("习惯不存在或无权限");
        }
        String date = body.get("date");
        return Result.success(checkInService.undoCheckIn(habitId, date));
    }

    @GetMapping("/logs")
    public Result<List<CheckInRecord>> logs(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            @RequestParam(required = false) Long habitId,
            HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        if (habitId != null) {
            Habit habit = habitService.getById(habitId);
            if (habit == null || !habit.getUserId().equals(userId)) {
                return Result.error("习惯不存在或无权限");
            }
        }
        return Result.success(checkInService.getCheckInLogs(userId, startDate, endDate, habitId));
    }

    @GetMapping("/detail/{id}")
    public Result<CheckInRecord> detail(@PathVariable Long id, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        return Result.success(checkInService.getCheckInDetail(id, userId));
    }

    @PostMapping("/quick")
    public Result<Boolean> quickCheckIn(@RequestBody CheckInRecord record, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        if (userId == null) {
            return Result.error("未登录");
        }

        try {
            record.setUserId(userId);

            boolean alreadyChecked = checkInService.isCheckedInToday(
                    userId,
                    record.getHabitId(),
                    record.getCheckInDate()
            );
            if (alreadyChecked) {
                return Result.error("今日已打卡，无需重复");
            }

            Habit habit = habitService.getById(record.getHabitId());
            if (habit == null || !habit.getUserId().equals(userId)) {
                return Result.error("习惯不存在或无权限");
            }

            record.setRemark("从服务卡片一键打卡");
            record.setImageUrl("");
            checkInService.checkIn(record);

            return Result.success(true);
        } catch (Exception e) {
            return Result.error("打卡失败: " + e.getMessage());
        }
    }

    @GetMapping("/card-data")
    public Result<CardDataVO> getCardData(
            @RequestParam("date") String date,
            HttpServletRequest request) {

        Long userId = getCurrentUserId(request);
        if (userId == null) {
            return Result.error("未登录");
        }

        try {
            List<Habit> habits = habitService.listByUserId(userId);
            Map<Long, Boolean> checkInStatus = checkInService.getCheckInStatus(userId, date);

            List<CardHabitItemVO> habitItems = new ArrayList<>();
            for (Habit habit : habits) {
                CardHabitItemVO item = new CardHabitItemVO();
                item.setId(habit.getId());
                item.setName(habit.getName());
                item.setIcon(habit.getIcon());
                item.setCheckedIn(checkInStatus.getOrDefault(habit.getId(), false));
                item.setDaily(habit.getCheckInType() == 1);
                habitItems.add(item);
            }

            long completed = habitItems.stream().filter(CardHabitItemVO::isCheckedIn).count();

            CardDataVO cardData = new CardDataVO();
            cardData.setLoggedIn(true);
            cardData.setCompletedCount((int) completed);
            cardData.setTotalCount(habitItems.size());
            cardData.setProgress(!habitItems.isEmpty() ? (int) (completed * 100 / habitItems.size()) : 0);
            cardData.setHabits(habitItems);
            cardData.setShowToast(false);
            cardData.setToastMessage("");

            return Result.success(cardData);
        } catch (Exception e) {
            return Result.error("获取卡片数据失败: " + e.getMessage());
        }
    }

    private Long getCurrentUserId(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        return userId != null ? (Long) userId : null;
    }
}
