// Voice capture — an input method, not a content type. Transcribed text lands
// in the writing surface as ordinary editable text. Uses the Web Speech API
// where available (stands in for the on-device Speech framework).

const Recognition = window.SpeechRecognition ?? window.webkitSpeechRecognition;

export const voiceSupported = Boolean(Recognition);

export function createRecorder({ onText, onStateChange, onError }) {
  if (!Recognition) return null;

  const rec = new Recognition();
  rec.continuous = true;
  rec.interimResults = false;
  rec.lang = 'en-US';

  let active = false;

  rec.onresult = (event) => {
    for (let i = event.resultIndex; i < event.results.length; i++) {
      if (event.results[i].isFinal) {
        onText(event.results[i][0].transcript.trim());
      }
    }
  };
  rec.onend = () => {
    if (active) {
      active = false;
      onStateChange(false);
    }
  };
  rec.onerror = (event) => {
    active = false;
    onStateChange(false);
    onError?.(event.error);
  };

  return {
    get recording() {
      return active;
    },
    toggle() {
      if (active) {
        active = false;
        rec.stop();
        onStateChange(false);
      } else {
        active = true;
        rec.start();
        onStateChange(true);
      }
    },
  };
}
