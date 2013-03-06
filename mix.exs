defmodule Genomu.Client.Mixfile do
  use Mix.Project

  def project do
    [ app: :genomu_client,
      version: "0.1",
      deps: deps ]
  end

  def genomu_path do
    System.get_env("GENOMU_PATH") || Path.expand("../../genomu/apps/genomu", __FILE__)
  end

  def application do
    [applications: [:exmsgpack],
     mod: {Genomu.Client.App, []},
    ]
  end

  defp deps do
     [
       {:exmsgpack,     github: "yrashk/exmsgpack"},
       {:jsx,           github: "talentdeficit/jsx"},
     ]
  end
end
