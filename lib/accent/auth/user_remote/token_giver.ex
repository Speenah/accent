defmodule Accent.UserRemote.TokenGiver do
  alias Accent.Repo
  alias Accent.Utils.SecureRandom

  def grant_token(user) do
    invalidate_tokens(user)
    create_token(user)
  end

  def grant_global_token(user) do
    Repo.insert!(%Accent.AccessToken{
      user_id: user.id,
      global: true,
      token: Accent.Utils.SecureRandom.urlsafe_base64(70)
    })
  end

  defp invalidate_tokens(user) do
    user
    |> Ecto.assoc(:private_access_tokens)
    |> Repo.update_all(set: [revoked_at: DateTime.utc_now(), updated_at: DateTime.utc_now()])
  end

  defp create_token(user) do
    token = Ecto.build_assoc(user, :access_tokens)
    token = %{token | token: SecureRandom.urlsafe_base64(70)}

    Repo.insert(token)
  end
end
