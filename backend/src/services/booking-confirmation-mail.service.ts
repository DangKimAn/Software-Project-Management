import Payment from "../models/payment";
import { notifyPaymentSuccess } from "../modules/notifications/notification.service";

export async function sendBookingConfirmationEmail(paymentId: number): Promise<void> {
    const payment = await Payment.findOne({
        where: {
            paymentId,
        },
    });

    if (!payment || payment.status !== "paid") {
        return;
    }

    await notifyPaymentSuccess(payment.paymentId);
}
