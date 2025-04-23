locals {
  # Import the payload:
  colors = yamldecode(file(var.manifest_path)) # Path to the YAML above

  # Iterate through outer list. I'm using 'hue' as my iterator to remove ambiguity with the sub field also called 'color':
  colored_fruits = [ for hue in local.colors : 

    # We assume that every color has a field called 'fruits' which is a list of objects
    # with properties name, size. Error handling is out of scope for the example.
    [ for fruit in hue.fruits : 

    # The {curly braces} indicate we are now building a two-dimensional field.
      {

        # Nested variables in Terraform inherit scope from their parents by default. That means that
        # each 'fruit' is aware of the fields in its parent, the 'color'.
        # 'hue' is the iterator for the outer list...

        color = hue.color

        # and 'fruit' is the iterator for the inner list.
        name  = fruit.name
        size  = fruit.size

        # What we've done here is consolidate these string values from two scopes (outer and inner)
        # to just one scope (this object).
        
        # We can also combine all these fields into something more useful.
        description = "This ${fruit.size}, ${hue.color} ${fruit.name} tastes ${hue.flavor}."
      }
      
      # Close the 'fruits' iterator:
    ]
    # Close the 'colors' iterator:
  ]
}

# Hypothetical value of local.colored_fruits, simplified for illustration:
# [
#   [
#     # Fields like color, name, and size omitted here for brevity.

#     { description = "This small, red strawberry tastes sweet." },
#     { description = "This big, red apple tastes sweet." }
#   ],
#   [
#     { description = "This small, green grape tastes tart." },
#     { description = "This big, green watermelon tastes tart." } # TODO: Verify sweetness of watermelons.
#   ]
# ]
