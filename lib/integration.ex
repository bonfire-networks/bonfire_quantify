# check that this extension is configured
Bonfire.Common.Config.require_extension_config!(:bonfire_quantify)

defmodule Bonfire.Quantify do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()
end
