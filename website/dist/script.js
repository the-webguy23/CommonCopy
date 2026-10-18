(() => {
  const toggle = document.querySelector('[data-menu-toggle]');
  const navigation = document.querySelector('[data-navigation]');
  if (toggle && navigation) {
    const closeNavigation = () => {
      toggle.setAttribute('aria-expanded', 'false');
      toggle.setAttribute('aria-label', 'Open navigation');
      navigation.dataset.open = 'false';
    };
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded));
      toggle.setAttribute('aria-label', expanded ? 'Open navigation' : 'Close navigation');
      navigation.dataset.open = String(!expanded);
    });
    navigation.addEventListener('click', event => { if (event.target.closest('a')) closeNavigation(); });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        closeNavigation(); toggle.focus();
      }
    });
    document.addEventListener('click', event => { if (!event.target.closest('.site-header')) closeNavigation(); });
  }
  document.querySelectorAll('[data-current-year]').forEach(element => {
    element.textContent = String(new Date().getFullYear());
  });
  const helpModule = document.querySelector('[data-help-module]');
  if (helpModule) {
    const tabs = Array.from(helpModule.querySelectorAll('[data-help-tab]'));
    const panels = Array.from(helpModule.querySelectorAll('[data-help-panel]'));
    const tabList = helpModule.querySelector('[data-help-tabs]');
    const topicFromHash = () => {
      const value = location.hash.slice(1);
      return tabs.findIndex(tab => tab.dataset.helpTab === value);
    };
    const selectTopic = (index, focus = false, updateUrl = false) => {
      tabs.forEach((tab, position) => {
        const selected = position === index;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        panels[position].hidden = !selected;
      });
      if (focus) tabs[index].focus();
      if (updateUrl) history.replaceState(null, '', '#' + tabs[index].dataset.helpTab);
    };
    tabList.setAttribute('role', 'tablist');
    tabs.forEach((tab, index) => {
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-controls', panels[index].id);
      panels[index].setAttribute('role', 'tabpanel');
      panels[index].setAttribute('aria-labelledby', tab.id);
      panels[index].tabIndex = 0;
      tab.addEventListener('click', event => {
        event.preventDefault();
        selectTopic(index, false, true);
      });
      tab.addEventListener('keydown', event => {
        if (event.key === ' ' || event.key === 'Enter') {
          event.preventDefault();
          selectTopic(index, false, true);
          return;
        }
        let next;
        if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
        else if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
        else if (event.key === 'Home') next = 0;
        else if (event.key === 'End') next = tabs.length - 1;
        else return;
        event.preventDefault();
        selectTopic(next, true, true);
      });
    });
    helpModule.dataset.tabsReady = 'true';
    selectTopic(Math.max(0, topicFromHash()));
    window.addEventListener('hashchange', () => {
      const index = topicFromHash();
      if (index >= 0) selectTopic(index);
    });
  }
  const message = document.querySelector('#demo-message');
  if (!message) return;
  const menu = document.querySelector('#example-menu');
  const openButton = document.querySelector('[data-open-demo]');
  const submenu = document.querySelector('[data-demo-submenu]');
  const feedback = document.querySelector('[data-demo-feedback]');
  const dialog = document.querySelector('[data-demo-dialog]');
  const form = document.querySelector('[data-demo-form]');
  const title = document.querySelector('#demo-title');
  const body = document.querySelector('#demo-body');
  const reply = ['A quick follow-up', 'Hi Alex,\n\nJust following up on my previous message. Let me know if you need anything else from me.\n\nThanks!'];
  const summaryPrompt = ['GPT → Summarize a document', 'Summarize the text below in three bullet points. Finish with one clear next step.\n\nText: [paste text here]'];
  const codeSnippet = ['JavaScript → Remove duplicates', 'const uniqueItems = [...new Set(items)];\nconsole.log(uniqueItems);'];
  const groups = {
    favourites: [reply, summaryPrompt],
    common: [reply, ['Email sign-off', 'Best regards,\nAlex Morgan']],
    prompts: [
      summaryPrompt,
      ['GPT → Write a follow-up', 'Write a polite, two-sentence follow-up asking whether there is an update on my request. Keep the tone friendly and professional.'],
      ['GPT → Review my code', 'Review the code below for bugs and readability. Suggest a corrected version and briefly explain each change.\n\nCode: [paste code here]'],
      ['Image based → Product photo', 'A minimalist product photograph of a white ceramic coffee cup on a pale stone surface. Soft window light from the left, gentle shadows, neutral background, no text.']
    ],
    code: [codeSnippet, ['CSS → Center a layout', '.container {\n  display: grid;\n  place-items: center;\n  min-height: 100vh;\n}']],
    daily: [reply, ['Email sign-off', 'Best regards,\nAlex Morgan'], ['Meeting confirmation', 'Thanks for confirming. I’ve added the meeting to my calendar and look forward to speaking with you.']]
  };
  const originalPromptCount = groups.prompts.length;
  let caret = 0, selectionEnd = 0, capturedSelection = '', activeGroup = null;
  const rememberSelection = () => {
    caret = message.selectionStart; selectionEnd = message.selectionEnd;
    capturedSelection = message.value.slice(caret, selectionEnd);
  };
  ['select', 'keyup', 'click', 'blur', 'input'].forEach(name => message.addEventListener(name, rememberSelection));
  function closeSubmenu() {
    submenu.hidden = true; activeGroup = null;
    document.querySelectorAll('[data-demo-group]').forEach(button => button.setAttribute('aria-expanded', 'false'));
  }
  function showMenu(visible) {
    closeSubmenu(); menu.hidden = !visible;
    openButton.setAttribute('aria-expanded', String(visible));
  }
  openButton.addEventListener('click', () => showMenu(menu.hidden));
  document.querySelectorAll('[data-demo-group]').forEach(button => button.addEventListener('click', () => {
    const group = button.dataset.demoGroup;
    if (activeGroup === group) { closeSubmenu(); return; }
    closeSubmenu(); activeGroup = group; button.setAttribute('aria-expanded', 'true'); submenu.replaceChildren();
    const heading = document.createElement('p');
    heading.textContent = group === 'prompts' ? 'Prompts / example subcategories' : button.firstChild.textContent.trim();
    submenu.append(heading);
    groups[group].forEach(([label, text]) => {
      const item = document.createElement('button'); item.type = 'button'; item.textContent = label;
      item.addEventListener('click', () => {
        message.value = message.value.slice(0, caret) + text + message.value.slice(selectionEnd);
        caret += text.length; selectionEnd = caret; capturedSelection = '';
        showMenu(false); message.focus(); message.setSelectionRange(caret, caret);
        feedback.textContent = 'Phrase inserted. The menu closes so you can keep going.';
      });
      submenu.append(item);
    });
    submenu.hidden = false;
  }));
  document.querySelectorAll('[data-platform]').forEach(button => button.addEventListener('click', () => {
    document.querySelectorAll('[data-platform]').forEach(other => other.setAttribute('aria-pressed', String(other === button)));
    const windows = button.dataset.platform === 'windows';
    document.querySelector('[data-demo-modifier]').textContent = windows ? 'Ctrl' : '⌘';
    feedback.textContent = windows ? 'Windows: Ctrl + right-click opens the menu.' : 'Mac: Command + right-click opens the menu.';
    showMenu(true);
  }));
  document.querySelector('[data-capture-demo]').addEventListener('click', () => {
    showMenu(false); title.value = capturedSelection ? 'My saved selection' : 'Summarize a document';
    title.setCustomValidity(''); body.setCustomValidity('');
    body.value = capturedSelection || summaryPrompt[1];
    dialog.showModal();
  });
  form.addEventListener('submit', event => {
    event.preventDefault();
    title.setCustomValidity(title.value.trim() ? '' : 'Add a phrase title.');
    body.setCustomValidity(body.value.trim() ? '' : 'Add some phrase text.');
    if (!form.reportValidity()) return;
    groups.prompts.push(['GPT → ' + title.value.trim(), body.value]);
    dialog.close(); showMenu(false);
    feedback.textContent = 'Saved under Prompts / GPT in this example. The editor closes automatically.';
  });
  [title, body].forEach(field => field.addEventListener('input', () => field.setCustomValidity('')));
  dialog.addEventListener('close', () => openButton.focus());
  document.querySelectorAll('[data-demo-cancel]').forEach(button => button.addEventListener('click', () => dialog.close()));
  document.querySelector('[data-demo-reset]').addEventListener('click', () => {
    message.value = ''; caret = selectionEnd = 0; capturedSelection = ''; groups.prompts.splice(originalPromptCount);
    showMenu(true); feedback.textContent = 'Choose a category, then a phrase.';
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !dialog.open && !menu.hidden) { showMenu(false); openButton.focus(); }
  });
  document.addEventListener('click', event => {
    if (!event.target.closest('.compact-menu, [data-open-demo], [data-platform], [data-demo-reset]')) showMenu(false);
  });
})();
