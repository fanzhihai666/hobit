package com.habit.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.habit.entity.Habit;
import com.habit.mapper.HabitMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class HabitService extends ServiceImpl<HabitMapper, Habit> {

    public List<Habit> getUserHabits(Long userId) {
        LambdaQueryWrapper<Habit> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Habit::getUserId, userId)
                .orderByDesc(Habit::getPriority);
        return list(wrapper);
    }

    public List<Habit> getUserDailyHabits(Long userId) {
        LambdaQueryWrapper<Habit> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Habit::getUserId, userId)
                .eq(Habit::getCheckInType, 1) // 每日打卡
                .orderByDesc(Habit::getPriority);
        return list(wrapper);
    }

    public List<Habit> getUserOnceHabits(Long userId) {
        LambdaQueryWrapper<Habit> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Habit::getUserId, userId)
                .eq(Habit::getCheckInType, 2) // 一次性打卡
                .orderByDesc(Habit::getCreateTime);
        return list(wrapper);
    }

    /**
     * 卡片专用：获取用户所有习惯
     */
    public List<Habit> listByUserId(Long userId) {
        LambdaQueryWrapper<Habit> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Habit::getUserId, userId)
                .orderByDesc(Habit::getPriority);
        return list(wrapper);
    }
}
