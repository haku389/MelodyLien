/**
 * supabase.js — Supabase Auth クライアント（B-2 認証最小構成）
 *
 * プロジェクト: StreetMelody (wngtvdgzzlkajtbwsurc / ap-northeast-1)
 * ログイン方法: メール / Google / Apple / LINE / ゲスト（匿名）
 *
 * - Google / Apple: Supabase Auth の OAuth（ダッシュボードでプロバイダ設定が必要）
 * - LINE: カスタム OIDC 連携（本実装で対応・プロトタイプでは未設定通知）
 * - ゲスト: 匿名認証。無効な場合は「ローカルゲスト」へフォールバック
 *   （LocalStorage のみで動作・サーバー同期なし・機能制限つき）
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const SUPABASE_URL = "https://wngtvdgzzlkajtbwsurc.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5";

const LOCAL_GUEST_KEY = "streetmelody.localGuest";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/** 現在の認証ユーザーを取得（ローカルゲスト含む）。未ログインは null */
export async function getAuthUser() {
  if (localStorage.getItem(LOCAL_GUEST_KEY) === "1") {
    return { id: "local_guest", email: null, isGuest: true, provider: "local" };
  }
  const { data } = await supabase.auth.getSession();
  const user = data?.session?.user;
  if (!user) return null;
  return {
    id: user.id,
    email: user.email || null,
    isGuest: !!user.is_anonymous,
    provider: user.app_metadata?.provider || "email",
  };
}

/** メール新規登録。確認メール設定が有効な場合 session は null */
export async function signUpEmail(email, password) {
  const { data, error } = await supabase.auth.signUp({ email, password });
  if (error) throw error;
  return { needsConfirm: !data.session };
}

/** メールログイン */
export async function signInEmail(email, password) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

/** OAuth ログイン（google / apple）。LINE はカスタム OIDC 前提 */
export async function signInOAuth(provider) {
  const { error } = await supabase.auth.signInWithOAuth({
    provider,
    options: { redirectTo: window.location.origin + window.location.pathname },
  });
  if (error) throw error;
}

/** ゲストログイン。匿名認証が無効ならローカルゲストにフォールバック */
export async function signInGuest() {
  const { error } = await supabase.auth.signInAnonymously();
  if (!error) return { local: false };
  // 匿名認証がプロジェクトで無効な場合
  localStorage.setItem(LOCAL_GUEST_KEY, "1");
  return { local: true };
}

export async function signOut() {
  localStorage.removeItem(LOCAL_GUEST_KEY);
  await supabase.auth.signOut();
}

export function onAuthChange(fn) {
  supabase.auth.onAuthStateChange((_event, session) => fn(session));
}
