// Today — the blank page is the home screen. Heading, meta, entries so far,
// and the writing surface with cursor ready. Just about the day: the dot
// grids live in the archive.

import { dayKey, entriesFor, addEntry, saveDraft, loadDraft } from '../store.js';
import { dayHeading, dayMetaRow, timeOfDay } from '../format.js';
import { voiceSupported, createRecorder } from '../voice.js';

const IDLE_COMMIT_MS = 5000;

export function renderToday(root) {
  const now = new Date();
  const key = dayKey(now);

  const heading = document.createElement('h1');
  heading.className = 'type-display';
  heading.textContent = dayHeading(now);

  const meta = document.createElement('div');
  meta.className = 'type-meta day-meta';

  const rule = document.createElement('hr');
  rule.className = 'day-rule';

  const list = document.createElement('div');
  list.className = 'entries';

  function entryNode(entry, settling = false) {
    const el = document.createElement('article');
    el.className = 'entry type-written';
    if (settling) el.classList.add('settling');
    const time = document.createElement('time');
    time.className = 'type-meta-small';
    time.textContent = timeOfDay(entry.at);
    el.appendChild(time);
    for (const para of entry.text.split(/\n{2,}/)) {
      const p = document.createElement('p');
      p.textContent = para;
      el.appendChild(p);
    }
    return el;
  }

  function refreshMeta() {
    meta.textContent = dayMetaRow(now, entriesFor(key));
  }

  function renderList(settlingId = null) {
    list.innerHTML = '';
    for (const entry of entriesFor(key)) {
      list.appendChild(entryNode(entry, entry.id === settlingId));
    }
  }

  renderList();
  refreshMeta();

  // --- Writing surface ---

  const writing = document.createElement('div');
  writing.className = 'writing';
  const textarea = document.createElement('textarea');
  textarea.placeholder = entriesFor(key).length ? 'Write, or speak.' : 'Write, or speak. This page is yours.';
  textarea.rows = 1;
  textarea.value = loadDraft();
  writing.appendChild(textarea);

  function autosize() {
    textarea.style.height = 'auto';
    textarea.style.height = `${textarea.scrollHeight}px`;
  }

  const ack = document.createElement('span');
  ack.className = 'type-meta-small save-ack';

  let ackTimer = null;
  function acknowledge(text) {
    ack.textContent = text;
    ack.classList.add('visible');
    clearTimeout(ackTimer);
    ackTimer = setTimeout(() => ack.classList.remove('visible'), 2200);
  }

  let idleTimer = null;

  function commit() {
    clearTimeout(idleTimer);
    const text = textarea.value.trim();
    if (!text) return;
    const entry = addEntry(text);
    textarea.value = '';
    saveDraft('');
    autosize();
    renderList(entry.id);
    refreshMeta();
    acknowledge(`saved ${timeOfDay(entry.at)}`);
    textarea.placeholder = 'Write, or speak.';
  }

  textarea.addEventListener('input', () => {
    autosize();
    saveDraft(textarea.value);
    clearTimeout(idleTimer);
    if (textarea.value.trim()) idleTimer = setTimeout(commit, IDLE_COMMIT_MS);
  });
  textarea.addEventListener('blur', commit);
  textarea.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') commit();
  });

  // --- Voice capture ---

  const captureRow = document.createElement('div');
  captureRow.className = 'capture-row';

  const speak = document.createElement('button');
  speak.type = 'button';
  speak.className = 'speak';
  const speakDot = document.createElement('span');
  speakDot.className = 'speak-dot';
  const speakLabel = document.createElement('span');
  speakLabel.className = 'type-meta-small';
  speakLabel.textContent = 'speak';
  speak.append(speakDot, speakLabel);

  const recorder = createRecorder({
    onText(text) {
      const sep = textarea.value && !textarea.value.endsWith(' ') ? ' ' : '';
      textarea.value += sep + text;
      textarea.dispatchEvent(new Event('input'));
    },
    onStateChange(recording) {
      speak.classList.toggle('recording', recording);
      speakLabel.textContent = recording ? 'listening' : 'speak';
    },
    onError() {
      acknowledge('voice unavailable');
    },
  });

  speak.addEventListener('click', () => {
    if (!voiceSupported || !recorder) {
      acknowledge('voice unavailable in this browser');
      return;
    }
    recorder.toggle();
  });

  captureRow.append(speak, ack);
  writing.appendChild(captureRow);

  root.append(heading, meta, rule, list, writing);

  // Cursor ready — the app opens writable
  requestAnimationFrame(() => textarea.focus({ preventScroll: true }));
  autosize();

  return {
    teardown() {
      commit(); // navigating away commits the session
      recorder?.recording && recorder.toggle();
    },
  };
}
