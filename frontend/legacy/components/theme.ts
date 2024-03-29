import "./theme.css";

const DEFAULT_TOGGLE_ID = "theme-toggle";

const getToggle = (id?: string): HTMLElement | null => {
  if (!id) {
    id = DEFAULT_TOGGLE_ID;
  }
  let btn = document.getElementById(id);
  return btn;
};

const loadTheme = (key: string): Theme => {
  let res = localStorage.getItem(key);
  if (res == null) {
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)");
    return prefersDark.matches ? Theme.Dark : Theme.Light;
  }
  return parseInt(res);
};

export enum Theme {
  Dark,
  Light,
}

export class ThemeManager {
  theme: Theme;
  themeToggle: HTMLInputElement;

  constructor(toggleId?: string) {
    this.theme = loadTheme("theme");
    let toggle = getToggle(toggleId);
    if (toggle == null) {
      // throw new Error("could not get theme toggle button");
      console.error("could not get theme toggle button");
    }
    this.themeToggle = toggle as HTMLInputElement;
    switch (this.theme) {
      case Theme.Dark:
        document.body.classList.toggle("dark-theme");
        break;
      case Theme.Light:
        document.body.classList.toggle("light-theme");
        if (this.themeToggle != null && "checked" in this.themeToggle) {
          this.themeToggle.checked = true;
        }
        break;
    }
  }

  toggle() {
    if (this.theme == Theme.Dark) {
      document.body.classList.remove("dark-theme");
      document.body.classList.add("light-theme");
      this.theme = Theme.Light;
    } else {
      document.body.classList.remove("light-theme");
      document.body.classList.add("dark-theme");
      this.theme = Theme.Dark;
    }
    localStorage.setItem("theme", this.theme.toString());
  }

  onChange(fn: (ev: Event) => void) {
    this.themeToggle.addEventListener("change", fn);
  }
}

export const applyTheme = () => {
  let man = new ThemeManager(DEFAULT_TOGGLE_ID);
  man.onChange((ev: Event) => {
    man.toggle();
  });
};
