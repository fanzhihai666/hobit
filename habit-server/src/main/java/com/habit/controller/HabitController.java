package com.habit.controller;

import com.habit.common.Result;
import com.habit.entity.Habit;
import com.habit.service.HabitService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.List;

@RestController
@RequestMapping("/api/habit")
public class HabitController {
    @Autowired
    private HabitService habitService;

    @GetMapping("/list")
    public Result<List<Habit>> list(HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        if (userId == null) {
            return Result.error("用户未登录");
        }
        return Result.success(habitService.getUserHabits(userId));
    }

    @PostMapping("/add")
    public Result<Boolean> add(@RequestBody Habit habit, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        habit.setUserId(userId);
        return Result.success(habitService.save(habit));
    }

    @PostMapping("/update")
    public Result<Boolean> update(@RequestBody Habit habit, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        Habit existing = habitService.getById(habit.getId());
        if (existing == null || !existing.getUserId().equals(userId)) {
            return Result.error("习惯不存在或无权限");
        }
        habit.setUserId(userId);
        return Result.success(habitService.updateById(habit));
    }

    @DeleteMapping("/{id}")
    public Result<Boolean> delete(@PathVariable Long id, HttpServletRequest request) {
        Long userId = getCurrentUserId(request);
        Habit habit = habitService.getById(id);
        if (habit == null || !habit.getUserId().equals(userId)) {
            return Result.error("习惯不存在或无权限");
        }
        return Result.success(habitService.removeById(id));
    }

    private Long getCurrentUserId(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        return userId != null ? (Long) userId : null;
    }
}
