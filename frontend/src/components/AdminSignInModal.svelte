{#if open}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div class="admin-modal-overlay" role="dialog" onkeydown={handleKeydown}>
    <div class="admin-modal">
      <button class="admin-modal-close" onclick={cancel} aria-label="Zamknij">&times;</button>
      <h3 class="admin-modal-title">Logowanie administratora</h3>
      <p class="admin-modal-subtitle">Wprowadź dane logowania</p>
      {#if error}
        <div class="admin-error">{error}</div>
      {/if}
      <input
        type="email"
        class="admin-input"
        placeholder="Email"
        bind:value={email}
        onkeydown={(e) => { if (e.key === 'Enter') submit() }}
      />
      <input
        type="password"
        class="admin-input"
        placeholder="Haslo"
        bind:value={password}
        onkeydown={(e) => { if (e.key === 'Enter') submit() }}
      />
      <button class="admin-submit-btn" onclick={submit}>Zaloguj</button>
    </div>
  </div>
{/if}

<script lang="ts">
  let {
    open = false,
    error = '',
    onsubmit = (_email: string, _password: string) => {},
    oncancel = () => {},
  }: {
    open?: boolean
    error?: string
    onsubmit?: (email: string, password: string) => void
    oncancel?: () => void
  } = $props()

  let email = $state('')
  let password = $state('')

  function submit() {
    onsubmit(email, password)
  }

  function cancel() {
    oncancel()
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') cancel()
  }
</script>

<style>
  .admin-modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 200;
  }
  .admin-modal {
    background: #fff;
    border-radius: 10px;
    padding: 30px;
    width: 340px;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.2);
    position: relative;
  }
  .admin-modal-close {
    position: absolute;
    top: 10px;
    right: 12px;
    background: none;
    border: none;
    font-size: 22px;
    color: #999;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .admin-modal-close:hover {
    color: #333;
  }
  .admin-modal-title {
    font-size: 18px;
    font-weight: 700;
    margin-bottom: 6px;
    color: #222;
  }
  .admin-modal-subtitle {
    font-size: 13px;
    color: #888;
    margin-bottom: 20px;
  }
  .admin-error {
    color: #c33;
    font-size: 13px;
    margin-bottom: 10px;
  }
  .admin-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #ccc;
    border-radius: 6px;
    font-size: 14px;
    margin-bottom: 14px;
  }
  .admin-submit-btn {
    width: 100%;
    padding: 10px;
    border: none;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    background: #4a90d9;
    color: #fff;
  }
</style>
