defmodule AscentsWeb.Router do
  use AscentsWeb, :router

  import AscentsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AscentsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AscentsWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/media/:token", MediaController, :show
    live "/gyms", GymLive.Index
  end

  # Other scopes may use custom stacks.
  # scope "/api", AscentsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:ascents, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live "/components", AscentsWeb.Dev.ComponentGalleryLive
      live_dashboard "/dashboard", metrics: AscentsWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", AscentsWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", AscentsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/feed", FeedLive.Index
    live "/gyms/new", GymLive.New
    live "/gyms/:slug/settings", GymLive.Edit
    live "/gyms/:slug/members", GymLive.Members
    live "/gyms/:slug/problems", ProblemLive.Index
    live "/gyms/:slug/problems/new", ProblemLive.New
    live "/gyms/:slug/problems/:id/edit", ProblemLive.Edit
    live "/u/:username", ProfileLive.Show
    live "/users/stats", StatsLive.Show
    live "/users/settings/profile", ProfileLive.Edit
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
  end

  scope "/", AscentsWeb do
    pipe_through :browser

    live "/gyms/:slug", GymLive.Show
  end

  scope "/", AscentsWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
