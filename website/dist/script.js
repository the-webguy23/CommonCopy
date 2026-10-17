(() => {
  const toggle = document.querySelector('[data-menu-toggle]');
  const navigation = document.querySelector('[data-navigation]');
  if (toggle && navigation) {
    const closeNavigation = () => { toggle.setAttribute('aria-expanded', 'false'); navigation.dataset.open = 'false'; };
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded)); navigation.dataset.open = String(!expanded);
      toggle.setAttribute('aria-label', expanded ? 'Open navigation' : 'Close navigation');
    });
    navigation.addEventListener('click', event => { if (event.target.closest('a')) closeNavigation(); });
    document.addEventListener('keydown', event => { if (event.key === 'Escape') closeNavigation(); });
  }
  document.querySelectorAll('[data-current-year]').forEach(element => { element.textContent = String(new Date().getFullYear()); });
  const message = document.querySelector('#demo-message');
  if (!message) return;
  const submenu = document.querySelector('[data-demo-submenu]');
  const feedback = document.querySelector('[data-demo-feedback]');
  const dialog = document.querySelector('[data-demo-dialog]');
  const form = document.querySelector('[data-demo-form]');
  const title = document.querySelector('#demo-title');
  const body = document.querySelector('#demo-body');
  const groups = {
    favourites: [['A thoughtful reply', 'Thanks for reaching out. I’ll take a look and get back to you shortly.']],
    common: [['Email sign-off', 'Best regards,\nAlex']],
    prompts: [['GPT → Draft a clear reply', 'Draft a clear, friendly reply to the following message:'], ['Image based → Product photo', 'A softly lit product photograph on a warm, neutral background.']],
    code: [['HTML document', '<!doctype html>\n<html lang="en">\n</html>']],
    daily: [['Email sign-off', 'Best regards,\nAlex'], ['A thoughtful reply', 'Thanks for reaching out. I’ll take a look and get back to you shortly.']]
  };
  let caret = 0, selectionEnd = 0, capturedSelection = '', activeGroup = null;
  const rememberSelection = () => { caret = message.selectionStart; selectionEnd = message.selectionEnd; capturedSelection = message.value.slice(caret, selectionEnd); };
  ['select', 'keyup', 'click', 'blur'].forEach(name => message.addEventListener(name, rememberSelection));
  function closeSubmenu() { submenu.hidden = true; activeGroup = null; document.querySelectorAll('[data-demo-group]').forEach(button => button.setAttribute('aria-expanded', 'false')); }
  document.querySelectorAll('[data-demo-group]').forEach(button => button.addEventListener('click', () => {
    const group = button.dataset.demoGroup;
    if (activeGroup === group) { closeSubmenu(); return; }
    closeSubmenu(); activeGroup = group; button.setAttribute('aria-expanded', 'true'); submenu.replaceChildren();
    const heading = document.createElement('p'); heading.textContent = group === 'prompts' ? 'Prompts / example subcategories' : button.firstChild.textContent.trim(); submenu.append(heading);
    groups[group].forEach(([label, text]) => {
      const item = document.createElement('button'); item.type = 'button'; item.textContent = label;
      item.addEventListener('click', () => {
        message.value = message.value.slice(0, caret) + text + message.value.slice(selectionEnd);
        caret += text.length; selectionEnd = caret;
        closeSubmenu(); message.focus(); message.setSelectionRange(caret, caret);
        feedback.textContent = 'Phrase inserted. In the app, the menu closes and you keep working.';
      }); submenu.append(item);
    }); submenu.hidden = false;
  }));
  document.querySelectorAll('[data-platform]').forEach(button => button.addEventListener('click', () => {
    document.querySelectorAll('[data-platform]').forEach(other => other.setAttribute('aria-pressed', String(other === button)));
    const windows = button.dataset.platform === 'windows';
    document.querySelector('[data-demo-modifier]').textContent = windows ? 'Ctrl' : '⌘';
    feedback.textContent = windows ? 'Windows: Ctrl + right-click opens the menu.' : 'Mac: Command + right-click opens the menu.';
    closeSubmenu();
  }));
  document.querySelector('[data-capture-demo]').addEventListener('click', () => {
    closeSubmenu(); title.value = 'My saved prompt';
    body.value = capturedSelection || 'Draft a clear, friendly reply to the following message:';
    dialog.showModal();
  });
  form.addEventListener('submit', event => {
    event.preventDefault();
    const phraseTitle = title.value.trim(), phraseBody = body.value.trim();
    if (!phraseTitle || !phraseBody) { body.setCustomValidity('Add a title and some phrase text.'); body.reportValidity(); return; }
    body.setCustomValidity(''); groups.prompts.push(['GPT → ' + phraseTitle, body.value]);
    dialog.close(); closeSubmenu(); feedback.textContent = 'Saved in this example. Open Prompts to insert it. The editor closes automatically.';
  });
  body.addEventListener('input', () => body.setCustomValidity(''));
  document.querySelectorAll('[data-demo-cancel]').forEach(button => button.addEventListener('click', () => dialog.close()));
  document.querySelector('[data-demo-reset]').addEventListener('click', () => {
    message.value = ''; caret = selectionEnd = 0; capturedSelection = ''; groups.prompts.splice(2);
    closeSubmenu(); feedback.textContent = 'Example reset. Choose a category, then a phrase.';
  });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') closeSubmenu(); });
  document.addEventListener('click', event => { if (!event.target.closest('.compact-menu')) closeSubmenu(); });
})();
