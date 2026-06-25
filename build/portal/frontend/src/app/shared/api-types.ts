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
