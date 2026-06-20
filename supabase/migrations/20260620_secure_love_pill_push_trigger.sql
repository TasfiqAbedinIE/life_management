-- This function is invoked only by its database trigger, never through RPC.
revoke execute on function public.enqueue_love_pill_push()
  from public, anon, authenticated;
