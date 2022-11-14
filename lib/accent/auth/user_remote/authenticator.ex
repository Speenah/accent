defmodule Accent.UserRemote.Authenticator do
  alias Accent.UserRemote.{CollaboratorNormalizer, Persister, TokenGiver, User}

  def authenticate(auth) do
    auth.info
    |> map_user(auth.provider, auth.extra)
    |> Persister.persist()
    |> CollaboratorNormalizer.normalize()
    |> TokenGiver.grant_token()
  end

  defp map_user(info, :dummy, _) do
    %User{
      provider: "dummy",
      fullname: info.email,
      email: normalize_email(info.email),
      uid: normalize_email(info.email)
    }
  end

  defp map_user(info, :discord, %{raw_info: %{user: user}}) do
    %User{
      provider: "discord",
      fullname: user.username <> "#" <> user.discriminator,
      picture_url: info.image,
      email: user.id <> "@fake-discord-email.com",
      uid: user.id
    }
  end

  defp normalize_email(email) do
    String.downcase(email)
  end
end
