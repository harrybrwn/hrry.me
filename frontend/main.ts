import "./main.css";
import {
  TOKEN_KEY,
  Token,
  loadToken,
  isExpired,
  login,
  deleteToken,
  storeToken,
  setCookie,
} from "./auth";
import { clearCookie } from "./util";
import { applyTheme } from "./theme";
import "./components/toggle";

function handleLogin(formID: string, callback: (t: Token) => void) {
  let formOrNull = document.getElementById(formID) as HTMLFormElement | null;
  if (formOrNull == null) {
    throw new Error("could not find element " + formID);
  }
  let form: HTMLFormElement = formOrNull;
  form.addEventListener("submit", function (event: SubmitEvent) {
    event.preventDefault();
    let formData = new FormData(form);
    login({
      username: formData.get("username") as string,
      email: formData.get("email") as string,
      password: formData.get("password") as string,
    })
      .then((tok: Token) => {
        callback(tok);
        form.reset();
      })
      .catch((error) => {
        console.error(error);
        let e = document.createElement("p");
        e.innerHTML = `${JSON.stringify(error)}`;
        form.appendChild(e);
      });
  });
}

function handleLogout(id: string, callback: () => void) {
  let btn = document.getElementById(id);
  if (btn == null) {
    console.error("could not find logout button");
    return;
  }
  btn.addEventListener("click", (ev: MouseEvent) => {
    callback();
  });
}

const SECOND = 1000;

const loginButtonID = "login-btn";
const loginPanelID = "login-panel";

class LoginPopup {
  loginBtn: HTMLElement;
  loginPanel: HTMLElement;
  open: boolean;
  constructor() {
    this.open = false;
    this.loginBtn =
      document.getElementById(loginButtonID) ||
      document.createElement("button");
    this.loginPanel =
      document.getElementById(loginPanelID) || document.createElement("div");
  }

  toggle() {
    this.loginPanel.style.display = this.open ? "none" : "block";
    this.open = !this.open;
  }

  listen() {
    this.loginBtn.addEventListener("click", () => {
      this.toggle();
    });
  }
}

interface LoginManagerOptions {
  // The interval at which the manager checks to see if we are expired
  // TODO use setTimeout on a login event to handle this so we don't have to poll
  interval?: number;

  target?: EventTarget;
}

class LoginManager {
  private expirationCheckTimer: NodeJS.Timer;
  private target: EventTarget;

  private tokenChange<K extends keyof TokenChangeEventHandlersEventMap>(
    name: K,
    tok: Token | null
  ): TokenChangeEvent {
    return new CustomEvent(name, {
      detail: {
        signedIn: tok != null,
        token: tok,
        action: tok == null ? "logout" : "login",
      },
    });
  }

  constructor(options: LoginManagerOptions) {
    this.target = options.target || document;
    // load the token and check expiration on startup
    let token = loadToken();
    if (token != null && !isExpired(token)) {
      this.login(token);
    }
    this.expirationCheckTimer = setInterval(() => {
      let token = loadToken();
      if (token == null) {
        return;
      }
      if (isExpired(token)) {
        this.logout();
      } else {
        console.log("token still valid");
      }
    }, options.interval || 60 * SECOND);
  }

  logout() {
    this.target.dispatchEvent(this.tokenChange("tokenChange", null));
    this.target.dispatchEvent(this.tokenChange("loggedIn", null));
  }

  login(tk: Token) {
    this.target.dispatchEvent(this.tokenChange("tokenChange", tk));
    this.target.dispatchEvent(this.tokenChange("loggedIn", tk));
  }

  stop() {
    clearInterval(this.expirationCheckTimer);
  }
}

const main = () => {
  applyTheme();
  let loginManager = new LoginManager({ interval: 5 * 60 * SECOND });
  let loginPanel = new LoginPopup();
  let main = document.getElementsByTagName("main")[0];

  document.addEventListener("tokenChange", (ev: TokenChangeEvent) => {
    const e = ev.detail;
    if (e.action == "login") {
      storeToken(e.token);
      setCookie(e.token);
    } else {
      clearCookie(TOKEN_KEY);
      deleteToken();
    }
  });

  loginPanel.listen();
  handleLogout("logout-btn", () => {
    loginManager.logout();
  });
  handleLogin("login-form", (tok: Token) => {
    loginManager.login(tok);
    loginPanel.toggle();
  });

  document.addEventListener("keydown", (ev: KeyboardEvent) => {
    const e = ev.target as HTMLElement;
    if (e.tagName == "INPUT" || e.tagName == "TEXTAREA") {
      return;
    }
    if (ev.key == "/" && ev.ctrlKey) {
      ev.preventDefault();
      loginPanel.toggle();
    }
  });

  let welcomeTicker = 0;
  let welcomeBanner = document.getElementsByClassName(
    "welcome-banner"
  )[0] as HTMLElement;
  let colors = ["red", "blue", "mediumspringgreen", "purple", "pink", "yellow"];
  setInterval(() => {
    welcomeBanner.style.color = colors[welcomeTicker % colors.length];
    welcomeTicker++;
  }, 500);
};

main();
