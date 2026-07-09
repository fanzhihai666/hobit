package com.habit.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("habit")
public class Habit {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String name;
    private String category;
    private Integer priority;
    private String remindTime;
    private String icon;

    /** 打卡类型：1每日打卡，2一次性打卡 */
    private Integer checkInType;

    /** 是否已完成（一次性打卡用） */
    private Integer isCompleted;

    private Integer isDeleted;
    private LocalDateTime createTime;

    /** 非持久化：今日是否已打卡（每日打卡用） */
    private transient Boolean todayCheckedIn;
}
