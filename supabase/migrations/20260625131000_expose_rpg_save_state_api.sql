-- ============================================================
-- EXPOSE RPG SAVE STATE TABLES TO SUPABASE REST API
-- ============================================================

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete
on public.player_state,
   public.triggered_dialogues,
   public.defeated_enemies,
   public.achievements
to authenticated;

grant select
on public.player_state,
   public.triggered_dialogues,
   public.defeated_enemies,
   public.achievements
to anon;

notify pgrst, 'reload schema';
