import request from './request'

export const adminApi = {
    login: (data) => request.post('/user/login', data),

    getStatistics: () => request.get('/admin/statistics'),
    getUserList: (params) => request.get('/admin/users', { params }),
    deleteUser: (id) => request.delete(`/admin/users/${id}`),
    updateUser: (id, data) => request.put(`/admin/users/${id}`, data),

    getHabitList: (params) => request.get('/admin/habits', { params }),
    deleteHabit: (id) => request.delete(`/admin/habits/${id}`),

    getCheckInList: (params) => request.get('/admin/checkin-records', { params }),
    deleteCheckIn: (id) => request.delete(`/admin/checkin-records/${id}`)
}
