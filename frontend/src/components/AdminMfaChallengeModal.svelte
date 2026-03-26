{#if open}
  <div class="admin-modal-overlay">
    <div class="admin-modal">
      <h3 class="admin-modal-title">Weryfikacja MFA</h3>
      <p class="admin-modal-subtitle">Wprowadz 6-cyfrowy kod z aplikacji</p>
      {#if error}
        <div class="admin-error">{error}</div>
      {/if}
      <input
        type="text"
        class="admin-input mfa-code-input"
        placeholder="000000"
        maxlength="6"
        bind:value={code}
        onkeydown={(e) => { if (e.key === 'Enter') verify() }}
      />
      <button class="admin-submit-btn mfa-verify-btn" onclick={verify}>Zweryfikuj</button>
    </div>
  </div>
{/if}

<script lang="ts">
  let {
    open = false,
    error = '',
    onverify = (_code: string) => {},
  }: {
    open?: boolean
    error?: string
    onverify?: (code: string) => void
  } = $props()

  let code = $state('')

  function verify() {
    onverify(code)
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
  .mfa-code-input {
    text-align: center;
    font-size: 20px;
    letter-spacing: 8px;
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
