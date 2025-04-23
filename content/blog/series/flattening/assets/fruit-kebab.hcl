locals{
  fruits = flatten(local.colored_fruits)
}

resource "fruit_chunk" "kebab" {
  # The key, or effective 'index', of each fruit_chunk in the kebab is its name.
  # This means we assume name is unique.
  for_each = { for fruit in local.fruits: fruit.name => fruit }

  # These strings are all direct attributes of the object.
  name   = each.value.name
  color  = each.value.color
  flavor = each.value.flavor
  # Normalize to permit either 'large' or 'big' as a descriptor of a big, yummy fruit
  large = contains(["large", "big"], each.value.size)
}