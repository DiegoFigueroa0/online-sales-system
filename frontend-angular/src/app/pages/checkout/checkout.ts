import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { ApiService, PaymentResult } from '../../services/api';

@Component({
  selector: 'app-checkout',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './checkout.html',
})
export class CheckoutComponent {
  cardNumber = '';
  result: PaymentResult | null = null;
  loading = false;
  error = '';

  constructor(private api: ApiService) {}

  async pay() {
    if (!this.cardNumber.trim()) {
      this.error = 'Ingresa un número de tarjeta';
      return;
    }
    this.loading = true;
    this.error = '';
    this.result = null;
    try {
      this.result = await this.api.checkout(this.cardNumber);
    } catch {
      this.error = 'Error al procesar el pago';
    } finally {
      this.loading = false;
    }
  }
}