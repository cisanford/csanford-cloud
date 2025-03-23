---
date: '2025-03-15'
draft: true
series: ["HCL Nested Fors"]
series_order: 1
slug: nested-for
summary: Let's break down how 'for' actually works in Terraform.
tags: ["terraform", "data structures", "iac"]
title: 'Part 1: Nested `for` statements and you'
weight: 1
---

## Prerequisites

- A `tuple` is an indexed array, similar to a list or a set `[which, are, comma, delimited, and, enclosed, in, square, brackets]`. However, while lists and sets always contain the same data type, a tuple contains an arbitrary collection of items. Terraform assumes a collection is a tuple if it isn't totally certain the type will be consistent. Since HCL prefers weak typing, it is appropriate in conversation (if not technical writing) to use `list` and `tuple` interchangeably. (You can also be pedantic about it to avoid being invited to more happy hours.)

- An `object` is like a two-dimensional `tuple` (contrary to a `map`, which needs to use consistent types such as a `map(string)`). Objects are `{collections of key-value pairs = enclosed in curly braces}`, where the keys are almost always strings and the values can be any valid variable value.
  - Unlike a `map`, where key/value pairs are usually always `string`s, an `object` can have values of any type - including other objects, or lists of other objects, or lists of lists of other objects.

Almost any value enclosed in `[square brackets]` is a one-dimensional collection (e.g. `tuple`), and almost any value enclosed in `{curly braces}` is a two-dimensional collection (e.g. `object`).
We need to keep this in mind when we look at `for`, because the Terraform `for` keyword lives `[inside a collection]`, not `outside(an expression)`.

> *The true, sinister nature of sub-objects becomes more evident when reviewing the plan or state of a module-heavy configuration, where you might find such identifiers as `module.vpc[0].module.default_security_group[0].aws_vpc_security_group_egress_rule.egress_rule[0].id`.*

## Part 1: What `for` does

Terraform uses the term 'for' in a handful of contexts. *This* usage is not to be confused with `for_each`, which is a meta-argument that iteratively defines multiple resources, data sources, and other constructs in state.

In a normal coding situation, `for` would define a loop which performs a task multiple times by iterating down a collection of similar arguments.
However, since HCL is incapable of performing any tasks except for variable manipulation, a  Terraform for can be thought of more like a 'directive' in string interpolation.

As I mentioned a moment ago, `for` operators are always used **within** a collection block, and they are part of the content of that collection. A `[for statement in square braces]` is a one-dimensional collection and a `{for statement in curly braces}` is a two-dimensional collection. Such statements are usually used if you need to bulk transform a collection of zero to many variables. 

For statements are structured as follows:
```text
[ for iterator in collection : output ]
# Iterator: arbitrary name to reference current item in collection
# Collection: Any complex object, but usually a one-dimensional one in this case
# Output: The command to transform the item

{ for i, j in collection : output-key => output-value }
# If 'collection' is two-dimensional, assign two iterators for key and value.
# If 'collection' is one-dimensional, the 'key' here is the index of the ordered list.
# The => operator is used specifically in a dynamic key-value setup like this.
### The key must be locally unique unless it's a grouping operation, which we'll talk about in a different post.
```

For example, if I have `var.companies = ['facebook', 'apple', 'pied piper']`, I could use this statement to brainstorm new tech startups:

```hcl
[ for company in var.companies : "New ${title(company)}" ]
```

<!-- trunk-ignore(markdownlint/MD038) -->
This would output `["New Facebook", "New Apple", "New Pied Piper"]`. The `for` statement outputs a new collection of strings, manipulating each input identically: `title` capitalizes the first letter of each word, and the `"string ${interpolation}"` prefixes '`New `' on the front.

However, we needn't necessarily convert a list of strings into another list of strings. For example, I can convert the one-dimensional `var.companies` into two-dimensional maps:

```hcl
[ for company in var.companies : {
  company = company
  better_company = "New ${title(company)}"
} ]
```

This would output a list of **objects**:
```text
[
  {
    company = "facebook"
    better_company = "New Facebook"
  },
  {
    company = "apple"
    better_company = "New Apple"
  },
  {
    company = "pied piper"
    better_company = "New Pied Piper"
  }
]
```

The same principles apply to a `for k, v` when the collection is two-dimensional.

## Part 2: Nesting `for`

Nested for statements are most commonly used if we need to consolidate lists of lists of objects. We'll dive into real-world examples in part 3 of this series, but on a high level the structure might look like this:

```hcl
locals {
  # Ingest a very complex input
  colors = [
    {
      color = "red"
      flavor = "sweet"
      fruits = [
        { 
          name = "strawberry"
          size = "small"
        },
        {
          name = "apple"
          size = "big"
        }
      ]
    },
    {
      color = "green"
      flavor = "tart"
      fruits = [
        {
          name = "grape"
          size = "small"
        },
        {
          name = "watermelon"
          size = "big"
        }
      ]
    }
  ]

  # Iterate through outer list. I'm using 'hue' as my iterator to remove ambiguity with the sub field also called 'color':
  colored_fruits = [ for hue in local.colors : 

    # We assume that every color has a field called 'fruits' which is a list of objects
    # with properties name, size. Error handling is out of scope for the example.
    [ for fruit in hue.fruits : 

    # Note that we are moving into {curly braces}, which means we're about to define
    # a two-dimensional field.
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
  # Get the heck out of this locals block, please
}
```

So after all is said and done, colored_fruits yields the following:

```text
[
  # Tuple of red things
  [
    {
      #...
      description = "This small, red strawberry tastes sweet."
    }
    {
      #...
      description = "This big, red apple tastes sweet."
    }
  ],
  # Tuple of green things
  [
    {
      #...
      description = "This small, green grape tastes tart."
    }
    {
      #...
      description = "This big, green watermelon tastes tart." # TODO: Add check block: Watermelons are sweet.
    }
  ]
]
```

While we are still dealing with nested *collections*, we are no longer dealing with nested *objects*. This gives us good uniformity to perform meaningful operations, including `flatten`.

We'll get into the practical usage and value of `flatten` in the next post. Until then, may the `for`s be with you.

---
