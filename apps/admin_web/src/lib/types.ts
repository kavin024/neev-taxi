export type AdminRole = 'super_admin' | 'admin' | 'support';

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
  is_active: boolean;
  last_login_at: string | null;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}

export interface DashboardData {
  kpis: {
    rides_today: number;
    completed_today: number;
    active_rides: number;
    online_captains: number;
    pending_captain_approvals: number;
    open_tickets: number;
    captured_payments_today_paise: number;
    captured_payments_today_display: string;
    platform_commission_today_paise: number;
    platform_commission_today_display: string;
  };
  ride_series: { date: string; rides: number; gmv_paise: number }[];
  category_breakdown: { category: string; rides: number }[];
  demo_data_present: boolean;
  generated_at: string;
  sources: string;
}

export interface PassengerRow {
  id: string;
  phone: string;
  masked_phone: string;
  name: string | null;
  status: string;
  is_demo: boolean;
  phone_verified: boolean;
  total_rides: number;
  rating: number | null;
  created_at: string;
  last_login_at: string | null;
}

export interface PassengerDetail {
  id: string;
  phone: string;
  role: string;
  status: string;
  is_demo: boolean;
  phone_verified: boolean;
  created_at: string;
  name?: string;
  photo_url?: string | null;
  passenger?: {
    name: string | null;
    email: string | null;
    photo_url: string | null;
    home_area: string | null;
    total_rides: number;
    rating: number | null;
  };
  rides: RideDetail[];
  tickets: { id: string; subject: string; status: string; created_at: string }[];
}

export interface CaptainRow {
  id: string;
  name: string;
  phone: string;
  status: string;
  verification_status: string;
  is_online: boolean;
  rating: number;
  total_trips: number;
  category: string | null;
  vehicle: string | null;
  pending_documents: number;
  is_demo: boolean;
  created_at: string;
}

export interface CaptainDocument {
  id: string;
  doc_type: string;
  status: string;
  original_filename: string;
  mime_type: string;
  size_bytes: number;
  rejection_reason: string | null;
  created_at: string;
}

export interface CaptainVehicle {
  id: string;
  category: string;
  reg_number: string;
  make_model: string;
  color: string;
  year: number | null;
  is_active: boolean;
}

export interface CaptainDetail {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  status: string;
  verification_status: string;
  rejection_reason: string | null;
  is_online: boolean;
  rating: number;
  total_trips: number;
  dl_masked: string | null;
  pan_masked: string | null;
  aadhaar_masked: string | null;
  lifetime_earnings_paise: number;
  lifetime_earnings_display: string;
  is_demo: boolean;
  created_at: string;
  approved_at: string | null;
  documents: CaptainDocument[];
  vehicles: CaptainVehicle[];
  trips: {
    id: string;
    ride_id: string;
    state: string;
    completed_at: string | null;
    final_fare_paise: number | null;
    payment_status: string | null;
  }[];
}

export interface RideRow {
  id: string;
  category: string;
  status: string;
  pickup: string;
  drop: string;
  fare_paise: number;
  fare_display: string;
  passenger_id: string;
  captain_id: string | null;
  trip_state: string | null;
  created_at: string;
}

export interface RideEvent {
  event_id: number;
  type: string;
  payload: Record<string, unknown> | null;
  created_at: string;
}

export interface RidePlace {
  lat: number;
  lng: number;
  address: string;
}

export interface RideDetail {
  id: string;
  category: string;
  status: string;
  payment_method: string;
  pickup: RidePlace;
  drop: RidePlace;
  distance_m: number;
  duration_s: number;
  quoted_fare_paise: number;
  quoted_fare_display: string;
  fare_breakdown: Record<string, unknown> | null;
  discount_paise: number;
  route_points: [number, number][] | { lat: number; lng: number }[];
  captain: {
    id: string;
    name: string;
    phone: string | null;
    rating: number;
    total_trips: number;
    photo_url: string | null;
  } | null;
  vehicle: {
    id: string;
    category: string;
    reg_number: string;
    make_model: string;
    color: string;
  } | null;
  trip: {
    id: string;
    state: string;
    payment_status: string;
    payment_method: string;
    start_pin: string | null;
    pin_expires_at: string | null;
    accepted_at: string | null;
    arrived_at: string | null;
    started_at: string | null;
    completed_at: string | null;
    final_fare_paise: number | null;
    final_fare_display: string | null;
    drop_verified: boolean;
    distance_m: number | null;
    duration_s: number | null;
  } | null;
  payment: {
    id: string;
    method: string;
    method_label: string;
    provider: string;
    status: string;
    amount_paise: number;
    amount_display: string;
    is_sandbox: boolean;
    signature_verified: boolean;
    created_at: string;
  } | null;
  expires_at: string | null;
  assigned_at: string | null;
  cancelled_at: string | null;
  cancelled_by: string | null;
  cancellation_reason: string | null;
  cancellation_fee_paise: number;
  cancellation_fee_display: string;
  possible_cancellation_fee_paise: number;
  created_at: string;
  version: number;
  passenger_id?: string;
  events?: RideEvent[];
}

export interface PricingRule {
  id: string;
  category: string;
  service_area_id: string | null;
  base_fare_paise: number;
  minimum_fare_paise: number;
  per_km_paise: number;
  per_minute_paise: number;
  waiting_per_minute_paise: number;
  cancellation_fee_paise: number;
  platform_fee_paise: number;
  commission_pct: number;
  night_multiplier: number;
  version: number;
  is_active: boolean;
  effective_from: string;
}

export interface ServiceCategory {
  id: string;
  code: string;
  display_name: string;
  description: string | null;
  capacity: number;
  is_active: boolean;
  sort_order: number;
}

export interface Coupon {
  id: string;
  code: string;
  description: string;
  discount_type: 'percent' | 'fixed';
  value: number;
  max_discount_paise: number | null;
  min_fare_paise: number;
  max_uses: number | null;
  per_user_limit: number;
  used_count: number;
  categories: string[] | null;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

export interface PowerPassPlan {
  id: string;
  code: string;
  name: string;
  description: string | null;
  price_paise: number;
  price_display: string;
  discount_pct: number;
  max_discount_paise: number;
  ride_limit: number;
  validity_days: number;
  is_active: boolean;
}

export interface TicketMessage {
  id: string;
  sender_type: string;
  body: string;
  created_at: string;
}

export interface SupportTicket {
  id: string;
  user_id: string;
  user_phone: string | null;
  user_role: string | null;
  ride_request_id: string | null;
  category: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
  resolution_notes: string | null;
  created_at: string;
  updated_at: string;
  resolved_at: string | null;
  messages: TicketMessage[];
}

export interface PaymentRow {
  id: string;
  user_id: string;
  ride_request_id: string | null;
  purpose: string;
  amount_paise: number;
  amount_display: string;
  method: string;
  provider: string;
  status: string;
  sandbox: boolean;
  signature_verified: boolean;
  created_at: string;
  captured_at: string | null;
}

export interface RefundRow {
  id: string;
  payment_id: string;
  user_id: string;
  ride_request_id: string | null;
  amount_paise: number;
  amount_display: string;
  reason: string;
  status: string;
  admin_note: string | null;
  provider_refund_id: string | null;
  created_at: string;
  processed_at: string | null;
}

export interface PayoutRow {
  id: string;
  captain_id: string;
  amount_paise: number;
  amount_display: string;
  method: string;
  destination_masked: string;
  status: string;
  requested_at: string;
  processed_at: string | null;
  admin_note: string | null;
  provider_reference: string | null;
}

export interface ServiceArea {
  id: string;
  name: string;
  city: string;
  center_lat: number;
  center_lng: number;
  radius_km: number;
  is_active: boolean;
}

export interface AppSetting {
  key: string;
  value: Record<string, unknown>;
  description: string | null;
  updated_at: string;
}

export interface AuditLog {
  id: number;
  actor_type: string;
  actor_id: string;
  action: string;
  entity_type: string;
  entity_id: string | null;
  before: unknown;
  after: unknown;
  ip_address: string | null;
  request_id: string | null;
  created_at: string;
}

export interface SafetyIncident {
  id: string;
  user_id: string;
  ride_request_id: string | null;
  status: string;
  lat: number | null;
  lng: number | null;
  contacts_notified: number;
  emergency_services_contacted: boolean;
  note: string | null;
  resolution: string | null;
  created_at: string;
  cancelled_at: string | null;
  resolved_at: string | null;
}
