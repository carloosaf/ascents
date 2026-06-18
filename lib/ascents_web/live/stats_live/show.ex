defmodule AscentsWeb.StatsLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Ascents, as: AscentLogs
  alias AscentsWeb.UserAuth

  def mount(_params, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    {:ok, stats} = AscentLogs.get_user_stats(current_scope, current_scope.user)

    {:ok,
     assign(socket,
       current_scope: current_scope,
       page_title: "My stats",
       stats: stats,
       grade_chart_json: chart_json(stats, :grade),
       gym_chart_json: chart_json(stats, :gym),
       timeline_chart_json: chart_json(stats, :timeline)
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="user-stats-show" class="space-y-6">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <span class="hold right-[10%] top-[18%] size-10 rotate-[20deg] bg-ascents-tape opacity-90">
          </span>
          <span class="hold right-[26%] bottom-[18%] size-8 rotate-[-18deg] bg-grade-blue opacity-80">
          </span>

          <div class="relative z-10 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="text-sm font-bold uppercase text-ascents-route-subtitle">
                Private progress
              </p>
              <h1 class="ascents-display mt-2 text-4xl leading-none text-ascents-route-title sm:text-5xl">
                My stats
              </h1>
            </div>

            <.link
              id="user-stats-profile-link"
              navigate={~p"/u/#{@current_scope.user.username}"}
              class="inline-flex items-center justify-center gap-2 rounded-md border border-ascents-line px-4 py-2 text-sm font-bold text-ascents-chalk transition hover:border-ascents-tape hover:text-ascents-tape"
            >
              <.icon name="hero-user" class="size-4" /> Profile
            </.link>
          </div>
        </section>

        <section id="user-stats-summary" class="ascents-stagger grid gap-4 sm:grid-cols-3">
          <.stat_block
            label="Sends"
            value={format_count(@stats.total_ascents)}
            detail="Logged ascents"
            tone="lime"
          />
          <.stat_block
            label="Gyms"
            value={format_count(@stats.unique_gyms)}
            detail="With logged ascents"
            tone="teal"
          />
          <.stat_block
            label="Routes"
            value={format_count(@stats.unique_routes)}
            detail="Unique problems sent"
            tone="blue"
          />
        </section>

        <%= if @stats.total_ascents > 0 do %>
          <div class="grid gap-4 lg:grid-cols-[minmax(0,1.08fr)_minmax(18rem,0.92fr)]">
            <section class="chalk-panel relative rounded-lg border border-ascents-line p-4">
              <div class="relative z-10 flex items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-ascents-muted">Recent pace</p>
                  <h2 class="mt-1 text-lg font-bold text-ascents-chalk">Last 12 weeks</h2>
                </div>
                <span class="rounded-md bg-ascents-info-soft px-2.5 py-1 text-xs font-black uppercase text-ascents-info-text">
                  Weekly
                </span>
              </div>
              <div
                id="user-stats-timeline-chart"
                phx-hook="StatsChart"
                phx-update="ignore"
                data-chart={@timeline_chart_json}
                class="ascents-chart-shell relative z-10 mt-4 h-72"
              >
                <canvas id="user-stats-timeline-chart-canvas" aria-label="Recent ascent timeline">
                </canvas>
              </div>
            </section>

            <section class="chalk-panel relative rounded-lg border border-ascents-line p-4">
              <div class="relative z-10">
                <p class="text-sm font-semibold text-ascents-muted">Gym distribution</p>
                <h2 class="mt-1 text-lg font-bold text-ascents-chalk">Where sends happen</h2>
              </div>
              <div
                id="user-stats-gym-chart"
                phx-hook="StatsChart"
                phx-update="ignore"
                data-chart={@gym_chart_json}
                class="ascents-chart-shell relative z-10 mt-4 h-72"
              >
                <canvas id="user-stats-gym-chart-canvas" aria-label="Gym ascent distribution">
                </canvas>
              </div>
            </section>
          </div>

          <section class="chalk-panel relative rounded-lg border border-ascents-line p-4">
            <div class="relative z-10 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p class="text-sm font-semibold text-ascents-muted">Grade distribution</p>
                <h2 class="mt-1 text-lg font-bold text-ascents-chalk">Sent grades</h2>
              </div>
              <div id="user-stats-grade-list" class="flex flex-wrap gap-2">
                <.grade_badge
                  :for={grade <- @stats.grade_distribution}
                  grade={grade.grade}
                  label={"#{grade.grade} x#{grade.count}"}
                />
              </div>
            </div>
            <div
              id="user-stats-grade-chart"
              phx-hook="StatsChart"
              phx-update="ignore"
              data-chart={@grade_chart_json}
              class="ascents-chart-shell relative z-10 mt-4 h-72"
            >
              <canvas id="user-stats-grade-chart-canvas" aria-label="Grade ascent distribution">
              </canvas>
            </div>
          </section>
        <% else %>
          <.empty_state
            id="user-stats-empty"
            title="No climbing activity yet"
            description="Your ascent totals, grade mix, gym split, and weekly timeline will appear here once you log sends."
            icon="hero-sparkles"
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp chart_json(stats, :grade) do
    stats.grade_distribution
    |> chart_payload("bar", "Ascents", :grade)
    |> Jason.encode!()
  end

  defp chart_json(stats, :gym) do
    stats.gym_distribution
    |> chart_payload("doughnut", "Ascents", :gym_name)
    |> Jason.encode!()
  end

  defp chart_json(stats, :timeline) do
    %{
      type: "line",
      label: "Ascents",
      labels: Enum.map(stats.timeline, & &1.label),
      values: Enum.map(stats.timeline, & &1.count)
    }
    |> Jason.encode!()
  end

  defp chart_payload(entries, type, label, key) do
    %{
      type: type,
      label: label,
      labels: Enum.map(entries, &Map.fetch!(&1, key)),
      values: Enum.map(entries, & &1.count)
    }
  end

  defp format_count(count) when is_integer(count), do: Integer.to_string(count)
end
