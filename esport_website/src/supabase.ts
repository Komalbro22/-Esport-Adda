import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://scdurogygxupczckioel.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjZHVyb2d5Z3h1cGN6Y2tpb2VsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MDE2MzYsImV4cCI6MjA4ODE3NzYzNn0.7j5m2MibEbEHnR46AbgncNecEXxpEGRAAwdHujKPjL0';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
