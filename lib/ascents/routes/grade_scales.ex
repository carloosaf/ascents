defmodule Ascents.Routes.GradeScales do
  @moduledoc """
  Supported bouldering grade scales for gym-scoped route setting.
  """

  @v_scale Enum.map(0..17, &"V#{&1}")
  @french [
    "4",
    "5",
    "5+",
    "6A",
    "6A+",
    "6B",
    "6B+",
    "6C",
    "6C+",
    "7A",
    "7A+",
    "7B",
    "7B+",
    "7C",
    "7C+",
    "8A",
    "8A+",
    "8B",
    "8B+",
    "8C",
    "8C+",
    "9A"
  ]

  @doc """
  Returns the allowed grades for a supported scale.
  """
  def grades_for_scale("french"), do: @french
  def grades_for_scale(_scale), do: @v_scale

  @doc """
  Returns select options for a supported scale.
  """
  def options_for_scale(scale), do: Enum.map(grades_for_scale(scale), &{&1, &1})

  @doc """
  Normalizes grade labels while preserving V-scale prefixes.
  """
  def normalize_grade(grade) when is_binary(grade) do
    grade
    |> String.trim()
    |> String.upcase()
  end

  def normalize_grade(grade), do: grade
end
