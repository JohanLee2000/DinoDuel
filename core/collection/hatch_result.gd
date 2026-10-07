class_name HatchResult
extends RefCounted
## What came out of one egg (or one craft) and what it did to the collection.

var dino: DinoDef
var shiny := false
## First time this dino joined the collection.
var is_new := false
## A Shiny duplicate turned the copy you already had Shiny.
var upgraded_to_shiny := false
## Amber gained because it was a duplicate (0 if it was kept).
var amber := 0
