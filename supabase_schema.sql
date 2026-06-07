-- Supabase Schema for TV Parental Control
-- Run this in the Supabase SQL Editor to set up your database

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Families table
create table families (
  id uuid primary key default uuid_generate_v4(),
  family_code text unique not null,
  owner_id uuid references auth.users(id) not null,
  created_at timestamptz default now()
);

-- Devices table
create table devices (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references families(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  device_name text not null,
  platform text not null default 'tv', -- 'tv' or 'phone'
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

-- Children table (synced from TV's local SQLite)
create table children (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references families(id) on delete cascade not null,
  local_id int not null,
  name text not null,
  avatar_color bigint not null,
  daily_limit_minutes int not null default 120,
  monday_allowed boolean not null default true,
  tuesday_allowed boolean not null default true,
  wednesday_allowed boolean not null default true,
  thursday_allowed boolean not null default true,
  friday_allowed boolean not null default true,
  saturday_allowed boolean not null default true,
  sunday_allowed boolean not null default true,
  allowed_start_hour int not null default 8,
  allowed_start_minute int not null default 0,
  allowed_end_hour int not null default 20,
  allowed_end_minute int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(family_id, local_id)
);

-- Usage records table
create table usage_records (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references families(id) on delete cascade not null,
  child_local_id int not null,
  device_id uuid references devices(id) on delete cascade,
  date text not null,
  used_minutes int not null default 0,
  session_count int not null default 1,
  created_at timestamptz default now(),
  unique(family_id, child_local_id, device_id, date)
);

-- Blocked apps table
create table blocked_apps (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references families(id) on delete cascade not null,
  child_local_id int not null,
  package_name text not null,
  app_label text not null,
  created_at timestamptz default now()
);

-- Activity logs table (for remote monitoring - Phase 3)
create table activity_logs (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references families(id) on delete cascade not null,
  child_local_id int not null,
  device_id uuid references devices(id) on delete cascade,
  app_name text not null,
  media_title text,
  created_at timestamptz default now()
);

-- Indexes
create index idx_children_family on children(family_id);
create index idx_usage_family_child on usage_records(family_id, child_local_id);
create index idx_usage_date on usage_records(date);
create index idx_blocked_family_child on blocked_apps(family_id, child_local_id);
create index idx_activity_family_child on activity_logs(family_id, child_local_id);
create index idx_activity_created on activity_logs(created_at desc);
create index idx_devices_family on devices(family_id);

-- Row Level Security (RLS)
alter table families enable row level security;
alter table devices enable row level security;
alter table children enable row level security;
alter table usage_records enable row level security;
alter table blocked_apps enable row level security;
alter table activity_logs enable row level security;

-- RLS Policies: users can only access data from families they belong to

-- Families: owner can do everything, members can read
create policy "owners can manage families"
  on families for all
  using (owner_id = auth.uid());

create policy "members can read family via devices"
  on families for select
  using (
    id in (select family_id from devices where user_id = auth.uid())
  );

-- Devices: users can manage their own devices, read family devices
create policy "users manage own devices"
  on devices for all
  using (user_id = auth.uid());

create policy "family members read devices"
  on devices for select
  using (
    family_id in (select family_id from devices where user_id = auth.uid())
  );

-- Children: family members can read and write
create policy "family members manage children"
  on children for all
  using (
    family_id in (select family_id from devices where user_id = auth.uid())
  );

-- Usage records: family members can read and write
create policy "family members manage usage"
  on usage_records for all
  using (
    family_id in (select family_id from devices where user_id = auth.uid())
  );

-- Blocked apps: family members can read and write
create policy "family members manage blocked apps"
  on blocked_apps for all
  using (
    family_id in (select family_id from devices where user_id = auth.uid())
  );

-- Activity logs: family members can read and write
create policy "family members manage activity"
  on activity_logs for all
  using (
    family_id in (select family_id from devices where user_id = auth.uid())
  );

-- Enable realtime for key tables
alter publication supabase_realtime add table children;
alter publication supabase_realtime add table usage_records;
alter publication supabase_realtime add table activity_logs;
alter publication supabase_realtime add table blocked_apps;
