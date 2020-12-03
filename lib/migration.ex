defmodule Bonfire.PublisherThesis.Migration do
  use Ecto.Migration

  defp mm(:up) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.PublisherThesis.AccessControl.Migration
      require Bonfire.PublisherThesis.Identity.Migration
      require Bonfire.PublisherThesis.Social.Migration
      Bonfire.PublisherThesis.AccessControl.Migration.migrate_me_access_control()
      Bonfire.PublisherThesis.Identity.Migration.migrate_me_identity()
      Bonfire.PublisherThesis.Social.Migration.migrate_me_social()
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
      Ecto.Migration.flush()
      Bonfire.PublisherThesis.Fixtures.insert()
    end
  end

  defp mm(:down) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.PublisherThesis.AccessControl.Migration
      require Bonfire.PublisherThesis.Identity.Migration
      require Bonfire.PublisherThesis.Social.Migration
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
      Bonfire.PublisherThesis.Social.Migration.migrate_me_social()
      Bonfire.PublisherThesis.Identity.Migration.migrate_me_identity()
      Bonfire.PublisherThesis.AccessControl.Migration.migrate_me_access_control()
    end
  end

  defmacro migrate_thesis() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mm(:up)),
        else: unquote(mm(:down))
    end
  end
  defmacro migrate_thesis(dir), do: mm(dir)

end
