defmodule DemoSeed do
  alias Ascents.Accounts
  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}
  alias Ascents.Gyms
  alias Ascents.Gyms.{Gym, GymMembership}
  alias Ascents.Media
  alias Ascents.Repo
  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Routes.BoulderProblem

  import Ecto.Query

  @demo_password "climbdemo123!"

  @demo_png_base64 """
  iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAg0lEQVR4nO2UQQqAIBBF3/97nYlJa0tpKhSz8MDiDrPSYCg2nc9ZQ3DXeoDeq/KhJ4BPo3fNcPAb/sMWZu67gEPdNwF/YJcBwJThh6PD7rY0bFK0C6BLju2W7KBqDVi46CxAPDe9VWEdrwAo0JYmci5DMwr+sJRsNBl7wKJ9SW8fPAMqBc4BEE4M2AAAAABJRU5ErkJggg==
  """

  def run do
    vela =
      ensure_user(%{
        email: "vela@ascents.local",
        username: "vela",
        display_name: "Vela Moreno",
        bio: "Weekend boulderer chasing quiet slab footwork and loud cave sessions."
      })

    rafi =
      ensure_user(%{
        email: "rafi@ascents.local",
        username: "rafi_beta",
        display_name: "Rafi Vega",
        bio: "Setter, gym owner, and believer in thoughtful warmups."
      })

    noor =
      ensure_user(%{
        email: "noor@ascents.local",
        username: "noor_sends",
        display_name: "Noor Haddad",
        bio: "Training power endurance and documenting the small breakthroughs."
      })

    vela_scope = Scope.for_user(vela)
    rafi_scope = Scope.for_user(rafi)
    noor_scope = Scope.for_user(noor)

    bloc =
      ensure_gym(rafi_scope, %{
        name: "Bloc District",
        slug: "bloc-district",
        location: "Madrid",
        grade_scale: "v_scale",
        description:
          "A compact bouldering community with a steep cave, comp wall, and weekly reset notes."
      })

    slab =
      ensure_gym(noor_scope, %{
        name: "Slab Lab",
        slug: "slab-lab",
        location: "Valencia",
        grade_scale: "french",
        description: "Technical boulders, balance drills, and friendly beta for patient climbers."
      })

    ensure_role(vela, bloc, "member")
    ensure_role(noor, bloc, "mod")
    ensure_role(vela, slab, "member")
    ensure_role(rafi, slab, "member")

    blue_rail =
      ensure_problem(rafi_scope, bloc, %{
        title: "Blue Rail",
        grade: "V3",
        color: "Blue",
        description: "Compression start into a left-hand rail and precise top-out."
      })

    pink_press =
      ensure_problem(rafi_scope, bloc, %{
        title: "Pink Press",
        grade: "V5",
        color: "Pink",
        description: "Shoulder-heavy press with a blind right foot under the lip."
      })

    old_cave =
      ensure_problem(rafi_scope, bloc, %{
        title: "Old Cave Link",
        grade: "V2",
        color: "Orange",
        description: "Archived demo route kept for historical moderation and ascent review."
      })

    archive_problem(rafi_scope, bloc, old_cave)

    quiet_feet =
      ensure_problem(noor_scope, slab, %{
        title: "Quiet Feet",
        grade: "6A",
        color: "Green",
        description: "A delicate slab line where every foot placement matters."
      })

    yellow_balance =
      ensure_problem(noor_scope, slab, %{
        title: "Yellow Balance",
        grade: "6B+",
        color: "Yellow",
        description: "High-step balance sequence with a calm final mantle."
      })

    reset_post =
      ensure_post(rafi_scope, bloc, %{
        body:
          "Fresh cave set is live. Blue Rail is the friendly intro, Pink Press is the shoulder test.",
        image?: true
      })

    ensure_comment(
      vela_scope,
      bloc,
      reset_post,
      "Blue Rail felt perfect for warming up. Saved Pink Press for tomorrow."
    )

    ensure_comment(
      noor_scope,
      bloc,
      reset_post,
      "Pink Press rewards staying square through the crux."
    )

    slab_post =
      ensure_post(noor_scope, slab, %{
        body: "Slab Lab reset note: Quiet Feet is all about breathing before the rockover.",
        image?: true
      })

    ensure_comment(vela_scope, slab, slab_post, "That rockover is humbling in the best way.")

    ensure_ascent_post(vela_scope, bloc, blue_rail, %{
      body: "Sent Blue Rail after dialing the left heel. Great benchmark problem.",
      climbed_at: "2026-06-12T10:30",
      image?: true
    })

    ensure_ascent_post(vela_scope, bloc, pink_press, %{
      body: "Finally held the press without cutting feet.",
      climbed_at: "2026-06-05T19:15",
      image?: true
    })

    ensure_ascent_post(vela_scope, slab, quiet_feet, %{
      body: "Quiet Feet went down once I stopped rushing the middle smear.",
      climbed_at: "2026-05-23T11:00",
      image?: false
    })

    ensure_ascent_post(rafi_scope, slab, yellow_balance, %{
      body: "Yellow Balance is a patience test. The high step is easier than it looks.",
      climbed_at: "2026-06-08T18:45",
      image?: false
    })

    IO.puts("Seeded Ascents demo data.")
    IO.puts("Demo login: vela@ascents.local / #{@demo_password}")

    IO.puts(
      "Visit /feed, /gyms/bloc-district, /gyms/slab-lab, and /users/stats after logging in."
    )
  end

  defp ensure_user(attrs) do
    user =
      case Accounts.get_user_by_email(attrs.email) do
        %User{} = user ->
          user

        nil ->
          {:ok, user} = Accounts.register_user(Map.take(attrs, [:email, :username]))
          user
      end

    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: @demo_password})

    user =
      if user.confirmed_at do
        user
      else
        user
        |> User.confirm_changeset()
        |> Repo.update!()
      end

    avatar_object_key =
      user.avatar_object_key || upload_demo_image!({:user, user}, "#{attrs.username}-avatar.png")

    {:ok, user} =
      user
      |> Scope.for_user()
      |> Accounts.update_user_profile(%{
        username: attrs.username,
        display_name: attrs.display_name,
        bio: attrs.bio,
        avatar_object_key: avatar_object_key
      })

    user
  end

  defp ensure_gym(owner_scope, attrs) do
    image_object_key =
      case Gyms.get_gym_by_slug(attrs.slug) do
        %Gym{image_object_key: key} when is_binary(key) and key != "" -> key
        _gym -> upload_demo_image!(:gym, "#{attrs.slug}.png")
      end

    attrs = Map.put(attrs, :image_object_key, image_object_key)

    gym =
      case Gyms.get_gym_by_slug(attrs.slug) do
        %Gym{} = gym -> gym
        nil -> create_gym!(owner_scope, attrs)
      end

    ensure_role(owner_scope.user, gym, "owner")

    {:ok, gym} =
      Gyms.update_gym(
        owner_scope,
        gym,
        Map.take(attrs, [:name, :description, :location, :grade_scale, :image_object_key])
      )

    gym
  end

  defp create_gym!(owner_scope, attrs) do
    {:ok, gym} = Gyms.create_gym(owner_scope, attrs)
    gym
  end

  defp ensure_role(%User{} = user, %Gym{} = gym, role) do
    now = DateTime.utc_now(:second)

    case Repo.get_by(GymMembership, user_id: user.id, gym_id: gym.id) do
      nil ->
        %GymMembership{user_id: user.id, gym_id: gym.id}
        |> GymMembership.changeset(%{role: role, joined_at: now})
        |> Repo.insert!()

      %GymMembership{} = membership ->
        membership
        |> GymMembership.changeset(%{role: role, joined_at: membership.joined_at || now})
        |> Repo.update!()
    end
  end

  defp ensure_problem(scope, gym, attrs) do
    problem =
      gym
      |> ClimbingRoutes.list_boulder_problems(include_archived: true)
      |> Enum.find(&(&1.title == attrs.title))

    image_object_key =
      case problem do
        %BoulderProblem{image_object_key: key} when is_binary(key) and key != "" -> key
        _problem -> upload_demo_image!(:problem, Path.basename(attrs.title) <> ".png")
      end

    attrs = Map.put(attrs, :image_object_key, image_object_key)

    case problem do
      %BoulderProblem{} = problem ->
        {:ok, problem} = ClimbingRoutes.update_boulder_problem(scope, gym, problem, attrs)
        problem

      nil ->
        {:ok, problem} = ClimbingRoutes.create_boulder_problem(scope, gym, attrs)
        problem
    end
  end

  defp archive_problem(scope, gym, %BoulderProblem{active: true} = problem) do
    {:ok, problem} = ClimbingRoutes.archive_boulder_problem(scope, gym, problem)
    problem
  end

  defp archive_problem(_scope, _gym, %BoulderProblem{} = problem), do: problem

  defp ensure_post(scope, gym, attrs) do
    post =
      Post
      |> where([post], post.gym_id == ^gym.id and post.user_id == ^scope.user.id)
      |> where([post], post.body == ^attrs.body and is_nil(post.deleted_at))
      |> order_by([post], asc: post.id)
      |> limit(1)
      |> Repo.one()

    image_object_key = image_key_for_existing(post, attrs, :post, "post.png")

    case post do
      %Post{} = post ->
        post
        |> Ecto.Changeset.change(image_object_key: image_object_key || post.image_object_key)
        |> Repo.update!()
        |> Repo.preload([:user, :gym, :comments])

      nil ->
        create_attrs = attrs |> Map.take([:body]) |> maybe_put_image_key(image_object_key)
        {:ok, post} = Feed.create_post(scope, gym, create_attrs)
        Feed.get_post(scope, gym, post.id)
    end
  end

  defp ensure_comment(scope, gym, post, body) do
    case Repo.get_by(Comment, post_id: post.id, user_id: scope.user.id, body: body) do
      %Comment{} = comment ->
        comment

      nil ->
        {:ok, comment} = Feed.create_comment(scope, gym, post, %{body: body})
        comment
    end
  end

  defp ensure_ascent_post(scope, gym, problem, attrs) do
    climbed_at = parse_climbed_at!(attrs.climbed_at)

    ascent =
      Repo.get_by(Ascent,
        user_id: scope.user.id,
        gym_id: gym.id,
        boulder_problem_id: problem.id,
        climbed_at: climbed_at
      )

    image_object_key =
      image_key_for_existing(ascent && Repo.get(Post, ascent.post_id), attrs, :post, "ascent.png")

    case ascent do
      %Ascent{} = ascent ->
        post = Repo.get!(Post, ascent.post_id)

        post
        |> Ecto.Changeset.change(
          body: attrs.body,
          image_object_key: image_object_key || post.image_object_key
        )
        |> Repo.update!()

      nil ->
        create_attrs =
          attrs
          |> Map.take([:body, :climbed_at])
          |> Map.put(:boulder_problem_id, problem.id)
          |> maybe_put_image_key(image_object_key)

        {:ok, %{post: post}} = AscentLogs.create_ascent_post(scope, gym, create_attrs)
        post
    end
  end

  defp image_key_for_existing(%{image_object_key: key}, _attrs, _owner, _filename)
       when is_binary(key) and key != "" do
    key
  end

  defp image_key_for_existing(_record, %{image?: true}, owner, filename) do
    upload_demo_image!(owner, filename)
  end

  defp image_key_for_existing(_record, _attrs, _owner, _filename), do: nil

  defp maybe_put_image_key(attrs, nil), do: attrs

  defp maybe_put_image_key(attrs, image_object_key),
    do: Map.put(attrs, :image_object_key, image_object_key)

  defp parse_climbed_at!(value) do
    value
    |> Kernel.<>(":00")
    |> NaiveDateTime.from_iso8601!()
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp upload_demo_image!(owner, filename) do
    png = @demo_png_base64 |> String.replace(~r/\s+/, "") |> Base.decode64!()

    path =
      Path.join(
        System.tmp_dir!(),
        "ascents-seed-#{System.unique_integer([:positive])}-#{filename}"
      )

    File.write!(path, png)

    try do
      case Media.upload_image(owner, path, filename, "image/png") do
        {:ok, object_key} -> object_key
        {:error, reason} -> raise "failed to upload demo image #{filename}: #{inspect(reason)}"
      end
    after
      File.rm(path)
    end
  end
end

DemoSeed.run()
