AGSScriptModule    Khris Running, Remapping Alternative Keyboard Movement 0.3 �(  // Alt Keyboard Movement module script

str_keys keys;
export keys;

int RunSpeed;
int LoopDomination;
int WalkView;
int IdleView, IdleDelay;
int RunView, RunSpeedX, RunSpeedY;
bool Moving;
bool Animating;
float DiagonalFactor;
bool AnimateAtEdge;
bool TurnIfBlocked = true;
bool Enabled = true;
int Mode;

static eKeyCode KeyboardMovement::GetKey(eKMKey key) {
  if (key == eKMKeyUp) return keys.Up;
  if (key == eKMKeyLeft) return keys.Left;
  if (key == eKMKeyDown) return keys.Down;
  if (key == eKMKeyRight) return keys.Right;
  if (key == eKMKeyRun) return keys.Run;
}

static void KeyboardMovement::SetKey(eKMKey key, eKeyCode k) {
  if (key == eKMKeyUp)    keys.Up = k;
  if (key == eKMKeyLeft)  keys.Left = k;
  if (key == eKMKeyDown)  keys.Down = k;
  if (key == eKMKeyRight) keys.Right = k;
}

static void KeyboardMovement::SetRunKey(eKMModificatorKeyCode k) {
  if (k >= 403 && k <= 407) keys.Run = k;
}

static void KeyboardMovement::SetMovementKeys(eKMMovementKeys mk) {
  if (mk == eKMMovementWASD) {
    KeyboardMovement.SetKey(eKMKeyUp, eKeyW);
    KeyboardMovement.SetKey(eKMKeyLeft, eKeyA);
    KeyboardMovement.SetKey(eKMKeyDown, eKeyS);
    KeyboardMovement.SetKey(eKMKeyRight, eKeyD);
  }
  if (mk == eKMMovementArrowKeys) {
    KeyboardMovement.SetKey(eKMKeyUp, eKeyUpArrow);
    KeyboardMovement.SetKey(eKMKeyLeft, eKeyLeftArrow);
    KeyboardMovement.SetKey(eKMKeyDown, eKeyDownArrow);
    KeyboardMovement.SetKey(eKMKeyRight, eKeyRightArrow);
  }
}

static int KeyboardMovement::GetRunSpeed() {
  return RunSpeed;
}  
static void KeyboardMovement::SetRunSpeed(int rs) {
  RunSpeed = rs;
}

static void KeyboardMovement::SetLoopDomination(eKMLoopDomination ld) {
  LoopDomination = ld;
}

static int KeyboardMovement::GetRunView() {
  return RunView;
}
static void KeyboardMovement::SetRunView(int rw, int rsx, int rsy) {
  RunView = rw;
  RunSpeedX = rsx;
  RunSpeedY = rsy;
}

static bool KeyboardMovement::Moving() {
  return Moving;
}
static bool KeyboardMovement::Animating() {
  return Animating;
}

static void KeyboardMovement::SetDiagonalFactor(float df) {
  DiagonalFactor = df;
}

static void KeyboardMovement::SetEdgeAnimation(bool aae) {
  AnimateAtEdge = aae;
}

static void KeyboardMovement::SetBlockedTurn(bool tib) {
  TurnIfBlocked = tib;
}

static bool KeyboardMovement::IsEnabled() {
  return Enabled;
}

static void KeyboardMovement::Disable() {
  Enabled = false;
}
static void KeyboardMovement::Enable() {
  Enabled = true;
}

static eKMMode KeyboardMovement::GetMode() {
  return Mode;
}
// for tapping mode: current xa, ya
int cxa, cya, rxa, rya;
static void KeyboardMovement::SetMode(eKMMode mode) {
  Mode = mode;
  cxa = 0;
  cya = 0;
  rxa = 0;
  rya = 0;
}

static void KeyboardMovement::StopMoving() {
  if (Mode == eKeyboardMovement_Tapping) {
    cxa = 0;
    cya = 0;
    rxa = 0;
    rya = 0;
  }
}

static void KeyboardMovement::SetIdleView(int view, int delay) {
  IdleView = view;
  IdleDelay = delay;
}

void game_start() {
  
  KeyboardMovement.SetMode();  // default: pressing
  
  // DIRECTIONAL KEYS
  KeyboardMovement.SetMovementKeys();  // default: WASD
  
  // RUN KEY MODIFICATOR
  KeyboardMovement.SetRunKey();  // default: Left Shift

  // RUN ANIMATION DELAY
  KeyboardMovement.SetRunSpeed();  // default: 2
  
  // DIAGONAL MOVEMENT WITHOUT DIAGONAL LOOPS USES
  KeyboardMovement.SetLoopDomination();  // default: last non-diagonal loop
  KeyboardMovement.SetDiagonalFactor(0.707);  
}

int walk_timer;

int Sgn(int i) {
  if (i < 0) return -1;
  if (i == 0) return 0;
  return 1;
}

int Abs(int i) {
  if (i == 0) return 0;
  return i/Sgn(i);
}

int xfree, yfree;

bool PathFree(int x, int y, int xa, int ya) {
  
  int i, j, step;
  bool go_x;
  if (Abs(xa) > Abs(ya)) { // horizontal domination
    step = Sgn(xa);
    go_x = true;
  }
  else step = Sgn(ya); // vertical domination
  
  xfree = x;
  yfree = y;
  
  if (go_x) {
    i = x+step;
    while (i != x+xa+step) {
      j = y + (ya*(i-x))/xa;
      if (GetWalkableAreaAt(i, j)) {
        xfree = i;
        yfree = j;
      }
      else i = x+xa;
      i += step;
    }
  }
  else {
    j = y+step;
    while (j != y+ya+step) {
      i = x + (xa*(j-y))/ya;
      if (GetWalkableAreaAt(i, j)) {
        xfree = i;
        yfree = j;
      }
      else j = y+ya;
      j += step;
    }
  }
  
  xfree -= x;
  yfree -= y;
  if (xfree == 0 && yfree == 0) return false;
  return true;
}

void AdvanceFrame(int xa, int ya, int l) {
    
  int sca = GetScalingAt(player.x, player.y);
  
  int sgn;
  if (player.ScaleMoveSpeed) {
    sgn = Sgn(xa);
    xa = (xa*sca)/100; if (xa == 0) xa = sgn;
    sgn = Sgn(ya);
    ya = (ya*sca)/100; if (ya == 0) ya = sgn;
  }
  bool free = PathFree(player.x - GetViewportX(), player.y - GetViewportY(), xa, ya);
  int x = player.x + xfree;
  int y = player.y + yfree;
    
  int pf = player.Frame;
  int pl = player.Loop;
  // advance frame
  pf++;
  // roll around
  if (pf >= Game.GetFrameCountForLoop(player.View, pl)) pf = 1;
  if (l != pl) { //player changes loop
    // translate frame to new loop
    // frame is 1-x
    // old last frame and new last frame
    int olf = Game.GetFrameCountForLoop(player.View, pl)-1;
    int nlf = Game.GetFrameCountForLoop(player.View, l)-1;
    if (olf != 1) pf = (pf*(nlf-1))/(olf-1);
    if (pf == 0) pf = 1;
  }
  // change loop
  if (free || TurnIfBlocked) {
    player.Loop = l;
  }
  // advance frame
  Animating = false;
  if (free || AnimateAtEdge) {
    Animating = true;
    ViewFrame *vf = Game.GetViewFrame(player.View, player.Loop, pf);
    if (vf.LinkedAudio != null) vf.LinkedAudio.Play();
    player.Frame = pf;
  }
  else player.Frame = 0;
  // move player
  Moving = false;
  if (free) {
    Moving = true;
    player.x = x;
    player.y = y;
  }
}

int GetNewLoop(int xa, int ya, int old_loop) {

  int loop;                        // loops:         xa
  int i = (Sgn(ya)+1)*3+Sgn(xa)+1; //            <0   0  >0
  String s = "7351X2604";          //         <0  7 | 3 | 5
  s = String.Format("%c", s.Chars[i]); //  ya  0  1 | X | 2
  loop = s.AsInt;                  //         >0  6 | 0 | 4
  
  if (player.DiagonalLoops && Game.GetLoopCountForView(player.View) < 8) player.DiagonalLoops = false;
  if (player.DiagonalLoops || loop < 4) return loop;
  
  // movement is diagonal but view doesn't have diagonal loops/DM is turned off
  int ld = LoopDomination;
  // old loop determines new loop domination
  if (ld == eKMLoopDLast) {
    if (old_loop == 0 || old_loop == 3) ld = eKMLoopDVertical;
    else                                ld = eKMLoopDHorizontal;
  }
  if (ld == eKMLoopDHorizontal) {
    if (loop < 6) return 2; // right
                  return 1; // left
  }
  if (ld == eKMLoopDVertical) {
    if ((loop/2)*2 == loop) return 0; // down
                            return 3; // up
  }
}

void HandleKeyPresses() {
    
  if (Mode == eKMModePressing) {
    rxa = 0;
    rya = 0;
    if (IsKeyPressed(keys.Left)) {
      if (!IsKeyPressed(keys.Right))   rxa = -player.WalkSpeedX;
    }
    else if (IsKeyPressed(keys.Right)) rxa =  player.WalkSpeedX;
    if (IsKeyPressed(keys.Up)) {
      if (!IsKeyPressed(keys.Down))    rya = -player.WalkSpeedY;
    }
    else if (IsKeyPressed(keys.Down))  rya =  player.WalkSpeedY;  
  }
}
  
void on_key_press(eKeyCode k) {
    
  if (!Enabled) return;
  
  if (Mode != eKeyboardMovement_Tapping) return;
  
  if (player.Moving) player.StopMoving();
  
  if (k == keys.Left) {
    if (cxa != -player.WalkSpeedX) {
      cxa = -player.WalkSpeedX;
      cya = 0;
    }
    else cxa = 0;
  }
  if (k == keys.Right) {
    if (cxa != player.WalkSpeedX) {
      cxa = player.WalkSpeedX;
      cya = 0;
    }
    else cxa = 0;
  }
  if (k == keys.Up) {
    if (cya != -player.WalkSpeedY) {
      cya = -player.WalkSpeedY;
      cxa = 0;
    }
    else cya = 0;
  }
  if (k == keys.Down) {
    if (cya != player.WalkSpeedY) {
      cya = player.WalkSpeedY;
      cxa = 0;
    }
    else cya = 0;
  }
    
  rxa = cxa;
  rya = cya;
}

bool was_animating = true;

void HandleMovement() {  
    
  HandleKeyPresses();
  int xa = rxa;
  int ya = rya;
  
  // reset frame timer to:
  int set_wt_to = player.AnimationSpeed;

  // running?
  if (IsKeyPressed(keys.Run) && !player.Moving) {
    // adjust timer reset
    set_wt_to = RunSpeed;
    // run view?
        
    if (RunView > 0) {
      // change view if necessary, store walk view
      if (player.View != RunView) {
        WalkView = player.View;
        player.ChangeView(RunView);
      }
      // adjust movement vars
      xa = (xa*RunSpeedX)/player.WalkSpeedX;
      ya = (ya*RunSpeedY)/player.WalkSpeedY;
    }
  }
  else if (player.View == RunView && WalkView > 0) player.ChangeView(WalkView);
  
  int loop = GetNewLoop(xa, ya, player.Loop);
  
  int sgn;
  if (walk_timer == 0) {
    if (xa == ya && xa == 0) {
      if (!player.Moving && was_animating) player.Frame = 0;
      Moving = false;
      Animating = false;
    }
    else if (xa*ya == 0) {  // horizontal or vertical movement
      if (player.Moving) player.StopMoving();
      walk_timer = set_wt_to;
      AdvanceFrame(xa, ya, loop);
    }
    else {                  // diagonal movement
      if (player.Moving) player.StopMoving();
      walk_timer = set_wt_to;
      sgn = Sgn(xa);
      xa = FloatToInt(IntToFloat(xa)*DiagonalFactor, eRoundNearest);
      if (xa == 0) xa = sgn;
      sgn = Sgn(ya);
      ya = FloatToInt(IntToFloat(ya)*DiagonalFactor, eRoundNearest);
      if (ya == 0) ya = sgn;
      AdvanceFrame(xa, ya, loop);
    }
  }
  else walk_timer--;
}

void repeatedly_execute() {
  if (Enabled) HandleMovement();
  
  if (IdleView == 0) IdleView = player.IdleView;
  if (KeyboardMovement.Animating() && !was_animating) player.SetIdleView(-1, 0);
  if (!KeyboardMovement.Animating() && was_animating) player.SetIdleView(IdleView, IdleDelay);
  was_animating = KeyboardMovement.Animating();
}  

void on_mouse_click(MouseButton button) {
  if (mouse.Mode == eModeWalkto) {
    rxa = 0;
    rya = 0;
  }
}


















 T  // new module header

enum eKMKey {
  eKMKeyUp,
  eKMKeyLeft,
  eKMKeyRight,
  eKMKeyDown,
  eKMKeyRun
};

enum eKMModificatorKeyCode {
  eKMModKeyLeftShift = 403,
  eKMModKeyRightShift = 404,
  eKMModKeyLeftCtrl = 405,
  eKMModKeyRightCtrl = 406,
  eKMModKeyAlt = 407
};

enum eKMMovementKeys {
  eKMMovementWASD,
  eKMMovementArrowKeys
};

struct str_keys {
  eKeyCode Up, Left, Down, Right;
  eKMModificatorKeyCode Run; 
};

enum eKMLoopDomination {
  eKMLoopDHorizontal,
  eKMLoopDVertical,
  eKMLoopDLast
};  

enum eKMMode {
  eKeyboardMovement_Tapping,  // old module contingency
  eKMModePressing
};

struct KeyboardMovement {
  // keys
  import static eKeyCode GetKey(eKMKey key);
  import static void SetKey(eKMKey key, eKeyCode k);
  import static void SetRunKey(eKMModificatorKeyCode k = eKMModKeyLeftShift);
  import static void SetMovementKeys(eKMMovementKeys mk = eKMMovementWASD);
  
  // settings
  import static int  GetRunSpeed();
  import static void SetRunSpeed(int RunSpeed = 2);
  import static void SetLoopDomination(eKMLoopDomination LoopDomination = eKMLoopDLast);
  import static int  GetRunView();
  import static void SetRunView(int RunView, int RunSpeedX, int RunSpeedY);
  import static void SetDiagonalFactor(float DiagonalFactor);
  import static void SetEdgeAnimation(bool AnimateAtEdge);
  import static void SetBlockedTurn(bool TurnIfBlocked);
  import static void SetIdleView(int view, int delay);
  
  // status
  import static bool Moving();
  import static bool Animating();

  // control
  import static eKMMode GetMode();
  import static void SetMode(eKMMode Mode = eKMModePressing);
  import static void Enable();
  import static void Disable();
  import static bool IsEnabled();
  import static void StopMoving();
};























 �b�S        ej��