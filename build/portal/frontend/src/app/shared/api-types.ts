export interface PaginatedResponse<T> {
  items?: T[];
  results?: T[];
  blog_posts?: T[];
  users?: T[];
  total?: number;
  count?: number;
  all_total?: number;
  active_total?: number;
  locked_total?: number;
  published_total?: number;
  draft_total?: number;
  scheduled_total?: number;
  offset?: number;
  limit?: number;
}

export interface AuthResponse {
  access_token: string;
  token_type?: string;
  expires_in?: number;
}

export interface ApiMessageResponse {
  message?: string;
  error?: string;
}

export interface UserSummary {
  id: number;
  name: string;
  email: string;
  role?: string;
  locked?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface BlogPostSummary {
  id: number;
  title: string;
  author?: string;
  content?: string;
  date?: string;
  visible?: boolean;
  tags?: string[];
  category?: string;
}

export interface BlogCommentSummary {
  id: number;
  content: string;
  user?: UserSummary;
  parent_comment_id?: number | null;
  created_at?: string;
  updated_at?: string;
}

export interface SettingValue {
  name: string;
  value: string;
}

export interface CountResponse {
  count: number;
}

export interface SchedulerStatus {
  state?: string;
  running?: boolean;
}

export interface SchedulerJob {
  id: string;
  name?: string;
  next_run_time?: string | null;
  trigger?: string;
}

export interface DumpVdl2Config {
  installed: boolean;
  active: boolean;
  ingest_active: boolean;
  frequencies: number[];
}

export interface DumpVdl2ConfigUpdate {
  frequencies: number[];
}

export interface AisTarget {
  id: number;
  mmsi: string;
  target_kind: string;
  imo?: string | null;
  callsign?: string | null;
  name?: string | null;
  vessel_type?: number | null;
  dimensions?: Record<string, unknown> | null;
  first_seen?: string | null;
  last_seen?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  speed?: number | null;
  course?: number | null;
  heading?: number | null;
  turn_rate?: number | null;
  navigation_status?: number | null;
  channel?: string | null;
  position_timestamp?: string | null;
  static_report_timestamp?: string | null;
}

export interface AisLiveResponse extends PaginatedResponse<AisTarget> {
  items: AisTarget[];
}

export interface AisPosition {
  id: number;
  target_id: number;
  received_at?: string | null;
  position_timestamp?: string | null;
  message_type: number;
  channel: string;
  latitude?: number | null;
  longitude?: number | null;
  speed?: number | null;
  course?: number | null;
  heading?: number | null;
}

export interface AisSettings {
  ais_map_enabled: string;
  ais_live_freshness_seconds: string;
  ais_history_retention_days: string;
  ais_raw_capture_enabled: string;
  ais_raw_retention_days: string;
}

export interface AisStats {
  targets: number;
  positions: number;
  voyages: number;
  raw_messages: number;
}
