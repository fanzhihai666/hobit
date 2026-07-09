package com.habit.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.habit.common.Result;
import com.habit.entity.CheckInRecord;
import com.habit.entity.Habit;
import com.habit.entity.User;
import com.habit.service.CheckInService;
import com.habit.service.HabitService;
import com.habit.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    @Autowired
    private UserService userService;
    @Autowired
    private HabitService habitService;
    @Autowired
    private CheckInService checkInService;

    /* ================= 用户管理 ================= */
    @GetMapping("/users")
    public Result<Page<User>> listUsers(
            @RequestParam(defaultValue = "1") int current,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) String keyword) {
        Page<User> page = new Page<>(current, size);
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        if (keyword != null && !keyword.isEmpty()) {
            wrapper.like(User::getUsername, keyword).or().like(User::getNickname, keyword);
        }
        wrapper.orderByDesc(User::getCreateTime);
        return Result.success(userService.page(page, wrapper));
    }

    @DeleteMapping("/users/{id}")
    public Result<Boolean> deleteUser(@PathVariable Long id) {
        return Result.success(userService.removeById(id));
    }

    @PutMapping("/users/{id}")
    public Result<Boolean> updateUser(@PathVariable Long id, @RequestBody User user) {
        user.setId(id);
        if (user.getPassword() == null || user.getPassword().isEmpty()) {
            user.setPassword(null);
        }
        return Result.success(userService.updateById(user));
    }

    /* ================= 习惯管理 ================= */
    @GetMapping("/habits")
    public Result<Page<Habit>> listHabits(
            @RequestParam(defaultValue = "1") int current,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) String keyword) {
        Page<Habit> page = new Page<>(current, size);
        LambdaQueryWrapper<Habit> wrapper = new LambdaQueryWrapper<>();
        if (keyword != null && !keyword.isEmpty()) {
            wrapper.like(Habit::getName, keyword);
        }
        wrapper.orderByDesc(Habit::getCreateTime);
        return Result.success(habitService.page(page, wrapper));
    }

    @DeleteMapping("/habits/{id}")
    public Result<Boolean> deleteHabit(@PathVariable Long id) {
        return Result.success(habitService.removeById(id));
    }

    /* ================= 打卡记录管理 ================= */
    @GetMapping("/checkin-records")
    public Result<Page<CheckInRecord>> listCheckInRecords(
            @RequestParam(defaultValue = "1") int current,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long habitId,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {
        Page<CheckInRecord> page = new Page<>(current, size);
        LambdaQueryWrapper<CheckInRecord> wrapper = new LambdaQueryWrapper<>();
        if (userId != null) wrapper.eq(CheckInRecord::getUserId, userId);
        if (habitId != null) wrapper.eq(CheckInRecord::getHabitId, habitId);
        if (startDate != null && !startDate.isEmpty()) wrapper.ge(CheckInRecord::getCheckInDate, startDate);
        if (endDate != null && !endDate.isEmpty()) wrapper.le(CheckInRecord::getCheckInDate, endDate);
        wrapper.orderByDesc(CheckInRecord::getCheckInTime);

        Page<CheckInRecord> result = checkInService.page(page, wrapper);
        for (CheckInRecord record : result.getRecords()) {
            Habit habit = habitService.getById(record.getHabitId());
            if (habit != null) {
                record.setHabitName(habit.getName());
                record.setHabitIcon(habit.getIcon());
            }
        }
        return Result.success(result);
    }

    @DeleteMapping("/checkin-records/{id}")
    public Result<Boolean> deleteCheckInRecord(@PathVariable Long id) {
        return Result.success(checkInService.removeById(id));
    }

    /* ================= 数据统计 Dashboard ================= */
    @GetMapping("/statistics")
    public Result<Map<String, Object>> statistics() {
        Map<String, Object> result = new HashMap<>();
        long userCount = userService.count();
        long habitCount = habitService.count();
        long checkInCount = checkInService.count();

        result.put("userCount", userCount);
        result.put("habitCount", habitCount);
        result.put("checkInCount", checkInCount);

        String today = LocalDate.now().toString();
        long todayCheckInCount = checkInService.lambdaQuery()
                .eq(CheckInRecord::getCheckInDate, today).count();
        result.put("todayCheckInCount", todayCheckInCount);

        List<Map<String, Object>> weekData = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            String date = LocalDate.now().minusDays(i).toString();
            String displayDate = LocalDate.now().minusDays(i)
                    .format(DateTimeFormatter.ofPattern("MM-dd"));
            long count = checkInService.lambdaQuery()
                    .eq(CheckInRecord::getCheckInDate, date).count();
            Map<String, Object> item = new HashMap<>();
            item.put("date", displayDate);
            item.put("count", count);
            weekData.add(item);
        }
        result.put("weekTrend", weekData);
        return Result.success(result);
    }
}
