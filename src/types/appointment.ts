export interface AppointmentItem {
    appointmentId: string;
    userId: string;
    personId?: string;
    appointmentDateTime: string;
    serviceName: string;
    fullName: string;
    email: string;
    phone: string;
    duration: number;
    price: number;
    paymentStatus: string;
    managementToken: string;
    notes?: string;
    status: string;
    createdAt: string;
    updatedAt: string;
  }
  