defmodule AscentsWeb.GymLive.Verification do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_verification_gym_by_slug!(slug)

    if Gyms.can_access_verification_workflow?(current_scope, gym) do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(
         :request_form,
         to_form(%{"verification_request_note" => ""}, as: :verification_request)
       )
       |> assign(
         :approval_form,
         to_form(%{"verification_note" => ""}, as: :verification_approval)
       )
       |> assign_verification_state(gym)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have access to this verification workflow.")
       |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("request-verification", %{"verification_request" => params}, socket) do
    case Gyms.request_verification(socket.assigns.current_scope, socket.assigns.gym, params) do
      {:ok, gym} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ownership verification request submitted for manual review.")
         |> assign_verification_state(gym)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           :request_form,
           to_form(Map.put(changeset, :action, :validate), as: :verification_request)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, verification_error(reason))}
    end
  end

  def handle_event("approve-verification", %{"verification_approval" => params}, socket) do
    case Gyms.approve_verification(socket.assigns.current_scope, socket.assigns.gym, params) do
      {:ok, gym} ->
        {:noreply,
         socket
         |> put_flash(:info, "Official gym ownership verified.")
         |> assign_verification_state(gym)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           :approval_form,
           to_form(Map.put(changeset, :action, :validate), as: :verification_approval)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, verification_error(reason))}
    end
  end

  def handle_event("revoke-verification", _params, socket) do
    case Gyms.revoke_verification(socket.assigns.current_scope, socket.assigns.gym) do
      {:ok, gym} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Official badge revoked. This is a community-managed gym page again."
         )
         |> assign(
           :request_form,
           to_form(%{"verification_request_note" => ""}, as: :verification_request)
         )
         |> assign(
           :approval_form,
           to_form(%{"verification_note" => ""}, as: :verification_approval)
         )
         |> assign_verification_state(gym)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, verification_error(reason))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="gym-verification-page" class="mx-auto max-w-3xl space-y-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-xs font-black uppercase tracking-[0.2em] text-ascents-tape">
              Ownership trust
            </p>
            <h1 class="mt-2 text-3xl font-black text-ascents-chalk">
              Verify {@gym.name}
            </h1>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-ascents-muted">
              Official badges are granted only after a manual platform review. Gym community
              roles cannot approve this request.
            </p>
          </div>
          <.button navigate={~p"/gyms/#{@gym.slug}"} variant="secondary">
            <.icon name="hero-arrow-left" class="size-4" /> Back to gym
          </.button>
        </div>

        <section
          id="gym-verification-current-state"
          class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
        >
          <div class="flex items-start gap-4">
            <div class={[
              "flex size-11 shrink-0 items-center justify-center rounded-lg",
              @gym.verification_status == "verified" &&
                "bg-emerald-500/15 text-emerald-300",
              @gym.verification_status == "pending" && "bg-amber-500/15 text-amber-300",
              @gym.verification_status == "community" &&
                "bg-ascents-panel-deep text-ascents-muted"
            ]}>
              <.icon name={status_icon(@gym.verification_status)} class="size-6" />
            </div>
            <div>
              <h2 class="text-lg font-black text-ascents-chalk">
                {status_title(@gym.verification_status)}
              </h2>
              <p class="mt-1 text-sm leading-6 text-ascents-muted">
                {status_description(@gym.verification_status)}
              </p>
            </div>
          </div>
        </section>

        <section
          :if={@gym.verification_status == "community" && @can_request_verification?}
          id="gym-verification-request-panel"
          class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
        >
          <h2 class="text-lg font-black text-ascents-chalk">Request official verification</h2>
          <p class="mt-2 text-sm leading-6 text-ascents-muted">
            Explain your relationship to the business and how the platform team can verify it.
            Do not include passwords or sensitive identity documents.
          </p>

          <.form
            for={@request_form}
            id="gym-verification-request-form"
            phx-submit="request-verification"
            class="mt-5 space-y-4"
          >
            <.input
              field={@request_form[:verification_request_note]}
              type="textarea"
              label="Verification details"
              placeholder="I manage this gym and can confirm ownership through..."
            />
            <.button
              id="gym-verification-request-submit"
              variant="primary"
              phx-disable-with="Submitting..."
            >
              <.icon name="hero-paper-airplane" class="size-4" /> Submit for review
            </.button>
          </.form>
        </section>

        <section
          :if={@gym.verification_status == "pending"}
          id="gym-verification-pending-details"
          class="chalk-panel rounded-lg border border-amber-400/30 bg-amber-400/5 p-5 sm:p-6"
        >
          <div class="flex items-center gap-2 text-amber-200">
            <.icon name="hero-clock" class="size-5" />
            <h2 class="text-lg font-black">Manual review pending</h2>
          </div>
          <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt class="font-bold text-ascents-muted">Requested by</dt>
              <dd class="mt-1 text-ascents-chalk">
                @{@gym.verification_requested_by_user.username}
              </dd>
            </div>
            <div>
              <dt class="font-bold text-ascents-muted">Requested</dt>
              <dd class="mt-1 text-ascents-chalk">
                {format_datetime(@gym.verification_requested_at)}
              </dd>
            </div>
          </dl>
          <div class="mt-4 rounded-md border border-ascents-line bg-ascents-panel-deep p-4">
            <p class="text-xs font-black uppercase tracking-wider text-ascents-muted">
              Claim details
            </p>
            <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-ascents-chalk-soft">
              {@gym.verification_request_note}
            </p>
          </div>
        </section>

        <section
          :if={@gym.verification_status == "pending" && @can_review_verification?}
          id="gym-verification-approval-panel"
          class="chalk-panel rounded-lg border border-emerald-400/30 p-5 sm:p-6"
        >
          <h2 class="text-lg font-black text-ascents-chalk">Platform review</h2>
          <p class="mt-2 text-sm leading-6 text-ascents-muted">
            Confirm the claim outside Ascents before granting the official badge.
          </p>
          <.form
            for={@approval_form}
            id="gym-verification-approval-form"
            phx-submit="approve-verification"
            class="mt-5 space-y-4"
          >
            <.input
              field={@approval_form[:verification_note]}
              type="textarea"
              label="Public verification note"
              placeholder="Verified through the gym's official business contact."
            />
            <.button
              id="gym-verification-approve-submit"
              variant="primary"
              phx-disable-with="Approving..."
            >
              <.icon name="hero-check-badge" class="size-4" /> Approve official badge
            </.button>
          </.form>
        </section>

        <section
          :if={@gym.verification_status == "verified"}
          id="gym-verification-approved-details"
          class="chalk-panel rounded-lg border border-emerald-400/30 bg-emerald-400/5 p-5 sm:p-6"
        >
          <div class="flex items-center gap-2 text-emerald-200">
            <.icon name="hero-check-badge" class="size-5" />
            <h2 class="text-lg font-black">Official ownership verified</h2>
          </div>
          <p class="mt-3 text-sm text-ascents-muted">
            Verified {format_datetime(@gym.verified_at)}
          </p>
          <p :if={@gym.verification_note} class="mt-3 text-sm leading-6 text-ascents-chalk-soft">
            {@gym.verification_note}
          </p>
          <.button
            :if={@can_review_verification?}
            id="gym-verification-revoke-button"
            phx-click="revoke-verification"
            data-confirm="Revoke this official badge and return the gym to community-managed status?"
            variant="secondary"
            class="mt-5"
          >
            <.icon name="hero-shield-exclamation" class="size-4" /> Revoke official badge
          </.button>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_verification_state(socket, gym) do
    gym = Gyms.get_verification_gym_by_slug!(gym.slug)

    assign(socket,
      gym: gym,
      can_request_verification?:
        Gyms.can_request_verification?(socket.assigns.current_scope, gym),
      can_review_verification?: Gyms.can_review_verification?(socket.assigns.current_scope)
    )
  end

  defp status_icon("verified"), do: "hero-check-badge"
  defp status_icon("pending"), do: "hero-clock"
  defp status_icon(_status), do: "hero-user-group"

  defp status_title("verified"), do: "Official gym page"
  defp status_title("pending"), do: "Verification pending"
  defp status_title(_status), do: "Community-managed gym"

  defp status_description("verified"),
    do: "Ascents has manually verified that this page is operated by the gym business."

  defp status_description("pending"),
    do: "A gym administrator submitted an ownership claim that is awaiting platform review."

  defp status_description(_status),
    do:
      "This page is maintained by the climbing community and is not an official business account."

  defp format_datetime(nil), do: "Unknown"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %-d, %Y at %H:%M UTC")
  end

  defp verification_error(:unauthorized), do: "You are not authorized to perform that action."
  defp verification_error(:invalid_transition), do: "That verification state has already changed."
  defp verification_error(_reason), do: "Unable to update gym verification."
end
