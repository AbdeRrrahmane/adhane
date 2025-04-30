package com.example.adhane_officiel

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class MyWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        // منطق المهمة هنا (مثل تشغيل الأذان أو عرض الإشعار)
        println("🔔 تم تنفيذ المهمة بواسطة WorkManager")

        // إرجاع نتيجة النجاح
        return Result.success()
    }
}