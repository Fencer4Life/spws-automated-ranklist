<!-- Stands in for CalendarView in tests that only need to know the calendar was
     shown and whether it was told an administrator is signed in. -->
<div class="calendar-view calendar-probe" data-is-admin={String(isAdmin)}></div>

<script lang="ts">
  let { isAdmin = false }: { isAdmin?: boolean; events?: unknown; showEvfToggle?: boolean } = $props()
</script>
