// UserMapper.java
package com.habit.mapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.habit.entity.User;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserMapper extends BaseMapper<User> {
}
