-- Fix Challenge RLS to support super_admin
DROP POLICY IF EXISTS "Admins can update challenges." ON public.challenges;
CREATE POLICY "Admins can update challenges." ON public.challenges FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND (role = 'admin' OR role = 'super_admin'))
);

DROP POLICY IF EXISTS "Participants can view results." ON public.challenge_results;
CREATE POLICY "Participants can view results." ON public.challenge_results FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.challenges WHERE id = challenge_id AND (creator_id = auth.uid() OR opponent_id = auth.uid()))
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND (role = 'admin' OR role = 'super_admin'))
);

DROP POLICY IF EXISTS "Users can view their fair score logs." ON public.fair_score_logs;
CREATE POLICY "Users can view their fair score logs." ON public.fair_score_logs FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND (role = 'admin' OR role = 'super_admin'))
);
