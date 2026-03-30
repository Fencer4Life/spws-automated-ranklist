{#if open}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div class="admin-modal-overlay" role="dialog" onkeydown={handleKeydown}>
    <div class="admin-modal mfa-enroll-modal">
      <button class="admin-modal-close" onclick={cancel} aria-label="Zamknij">&times;</button>
      <h3 class="admin-modal-title">Konfiguracja MFA</h3>
      <p class="admin-modal-subtitle">Zeskanuj kod QR aplikacja uwierzytelniajaca</p>
      {#if error}
        <div class="admin-error">{error}</div>
      {/if}
      <div class="mfa-qr-container">
        <img class="mfa-qr" src={qrCode} alt="MFA QR Code" />
      </div>
      <p class="mfa-secret-label">Klucz reczny:</p>
      <code class="mfa-secret">{secret}</code>
      <input
        type="text"
        class="admin-input mfa-code-input"
        placeholder="000000"
        maxlength="6"
        bind:value={code}
        onkeydown={(e) => { if (e.key === 'Enter') confirm() }}
      />
      <button class="admin-submit-btn mfa-confirm-btn" onclick={confirm}>Potwierdz</button>
    </div>
  </div>
{/if}

<script lang="ts">
  let {
    open = false,
    qrCode = '',
    secret = '',
    error = '',
    onconfirm = (_code: string) => {},
    oncancel = () => {},
  }: {
    open?: boolean
    qrCode?: string
    secret?: string
    error?: string
    onconfirm?: (code: string) => void
    oncancel?: () => void
  } = $props()

  let code = $state('')

  function confirm() {
    onconfirm(code)
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
    width: 380px;
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
  .mfa-qr-container {
    text-align: center;
    margin-bottom: 16px;
  }
  .mfa-qr {
    width: 200px;
    height: 200px;
  }
  .mfa-secret-label {
    font-size: 12px;
    color: #888;
    margin-bottom: 4px;
  }
  .mfa-secret {
    display: block;
    font-size: 13px;
    background: #f5f5f5;
    padding: 8px 12px;
    border-radius: 4px;
    margin-bottom: 16px;
    word-break: break-all;
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
