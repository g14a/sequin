defmodule SequinWeb.UserAuth do
  @moduledoc false
  use SequinWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias Sequin.Accounts
  alias Sequin.Repo

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_sequin_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn, redirect_to \\ ~p"/login") do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      SequinWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: redirect_to)
  end

  def log_in_user_with_impersonation(conn, impersonating_user, impersonated_user) do
    user_token = Accounts.generate_user_session_token(impersonating_user)
    impersonation_token = Accounts.generate_impersonation_token(impersonating_user, impersonated_user)

    conn
    |> renew_session()
    |> put_session(:user_token, user_token)
    |> put_session(:impersonation_token, impersonation_token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(user_token)}")
    |> redirect(to: signed_in_path(conn))
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    {impersonation_token, conn} = ensure_impersonation_token(conn)

    if user = user_token && Accounts.get_user_by_session_token(user_token) do
      if impersonation_token do
        case Accounts.get_impersonated_user_id(user, impersonation_token) do
          {:ok, impersonated_user_id} ->
            impersonated_user =
              impersonated_user_id
              |> Accounts.get_user!()
              |> Repo.preload([:accounts, :accounts_users])

            assign(conn, :current_user, %{user | impersonating_user: impersonated_user})

          _ ->
            assign(conn, :current_user, user)
        end
      else
        assign(conn, :current_user, user)
      end
    else
      assign(conn, :current_user, nil)
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  defp ensure_impersonation_token(conn) do
    if token = get_session(conn, :impersonation_token) do
      {token, conn}
    else
      {nil, conn}
    end
  end

  @doc """
  Clears the impersonation session data.
  """
  def clear_impersonation(conn) do
    conn
    |> delete_session(:impersonation_token)
    |> fetch_current_user([])
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule SequinWeb.PageLive do
        use SequinWeb, :live_view

        on_mount {SequinWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{SequinWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:toast, %{kind: :error, title: "Please log in to continue."})
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        user = Accounts.get_user_by_session_token(user_token)

        if impersonation_token = session["impersonation_token"] do
          case Accounts.get_impersonated_user_id(user, impersonation_token) do
            {:ok, impersonated_user_id} ->
              impersonated_user =
                impersonated_user_id
                |> Accounts.get_user!()
                |> Repo.preload([:accounts, :accounts_users])

              %{user | impersonating_user: impersonated_user}

            _ ->
              user
          end
        else
          user
        end
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.

  ## Options

    * `:unauthenticated_redirect` - Specifies where to redirect unauthenticated users.
      * `:login` - Redirects to the login page (default)
      * `:register` - Redirects to the registration page
  """
  def require_authenticated_user(conn, opts) do
    if conn.assigns[:current_user] do
      conn
    else
      {title, redirect_to} =
        case Keyword.get(opts, :unauthenticated_redirect, :login) do
          :login ->
            {"Please log in to continue.", ~p"/login"}

          :register ->
            {"Please register to continue.", ~p"/register"}
        end

      conn
      |> put_flash(:toast, %{kind: :error, title: title})
      |> maybe_store_return_to()
      |> redirect(to: redirect_to)
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
