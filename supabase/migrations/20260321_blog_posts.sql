-- Blog/News table for tips, updates, featured players
CREATE TABLE IF NOT EXISTS public.blog_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  excerpt text,
  content text NOT NULL,
  image_url text,
  author text DEFAULT 'Esport Adda',
  category text DEFAULT 'news',
  is_published boolean DEFAULT true,
  published_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_blog_posts_published ON public.blog_posts (is_published, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_blog_posts_slug ON public.blog_posts (slug);
CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON public.blog_posts (category);

ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Blog posts are viewable by everyone"
  ON public.blog_posts FOR SELECT
  USING (is_published = true);

CREATE POLICY "Admins can manage blog posts"
  ON public.blog_posts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- Seed sample posts
INSERT INTO public.blog_posts (slug, title, excerpt, content, category)
VALUES 
  (
    'how-to-join-your-first-tournament',
    'How to Join Your First Tournament',
    'A beginner''s guide to entering esport tournaments on Esport Adda and maximizing your chances of winning.',
    '# How to Join Your First Tournament

1. **Download the app** – Get Esport Adda from the Play Store or our website.
2. **Create an account** – Sign up with your email and complete your profile.
3. **Add funds** – Deposit via UPI or Razorpay to have entry fee balance.
4. **Browse tournaments** – Check upcoming tournaments for your favorite games.
5. **Register early** – Slots fill up fast! Join 10–15 minutes before start time.
6. **Get room details** – We''ll notify you with Room ID and Password before the match.
7. **Play & report** – Enter the room, play your best, and submit results when done.

Good luck, and may the best player win!',
    'tips'
  ),
  (
    'fair-play-system-explained',
    'Fair Play System Explained',
    'Learn how our anti-cheat and fair play scoring keeps competitions fair for everyone.',
    '# Fair Play System Explained

Our Fair Play system ensures every player competes on a level playing field.

## How It Works

- **Fair Score** – Each player has a score based on their match history and behavior.
- **Trusted Badge** – High scores earn the Trusted badge for faster matchmaking.
- **Verification** – Screenshots and results are reviewed to prevent cheating.
- **Dispute Resolution** – Any conflicts are resolved by our support team.

Play fair, win big!',
    'updates'
  )
ON CONFLICT (slug) DO NOTHING;
