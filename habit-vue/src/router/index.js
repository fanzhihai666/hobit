import { createRouter, createWebHistory } from 'vue-router'
import Login from '../views/Login.vue'
import Layout from '../views/Layout.vue'
import Dashboard from '../views/Dashboard.vue'
import UserManage from '../views/UserManage.vue'
import HabitManage from '../views/HabitManage.vue'
import CheckInManage from '../views/CheckInManage.vue'

const routes = [
    { path: '/login', component: Login },
    {
        path: '/',
        component: Layout,
        redirect: '/dashboard',
        children: [
            { path: 'dashboard', component: Dashboard },
            { path: 'users', component: UserManage },
            { path: 'habits', component: HabitManage },
            { path: 'checkins', component: CheckInManage }
        ]
    }
]

const router = createRouter({
    history: createWebHistory(),
    routes
})

router.beforeEach((to, from, next) => {
    const token = localStorage.getItem('admin_token')
    if (to.path !== '/login' && !token) {
        next('/login')
    } else {
        next()
    }
})

export default router
