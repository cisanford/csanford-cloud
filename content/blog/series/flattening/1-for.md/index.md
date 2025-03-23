---
date: '2025-03-23'
draft: false
series: ["HCL Nested Fors"]
series_order: 1
slug: nested-for
summary: Let's break down how 'for' actually works in Terraform.
tags: ["terraform", "data structures", "iac"]
title: 'Part 1: Nested `for` statements and you'
weight: 1
---

## Prerequisites

- A **tuple** is an indexed array, similar to a list or a set: `[comma, delimited, and, enclosed, in, square, brackets]`.
Unlike lists or sets, which must contain consistent data types, tuples can hold different data types simultaneously.
  - Terraform treats a collection as a tuple when it can't confidently assume type consistency, which is why you might often see references to "type tuple" in error messages even though you didn't make one on purpose.
  - Since Terraform's typing is very weak indeed, it's perfectly fine in conversation (if not technical writing) to use `list` and `tuple` interchangeably.

- An **object** resembles a two-dimensional tuple (in contrast to a **map**, which must consistently use a single data type, e.g., `map(string)`). Objects use `{key-value pairs}` syntax, where keys are typically strings, and values can be any valid Terraform type.
  - Keys for `object` items are still strings (i.e. attribute names), but **values** can be any type, including other objects or even deeply nested lists.

In Terraform:

- Values enclosed in `[square brackets]` are typically one-dimensional collections (tuples).
- Values enclosed in `{curly braces}` are typically two-dimensional collections (objects).

We want to keep this distinction in mind when working with the `for` keyword, as it appears **within** a collection rather than as a standalone expression.

> *The sinister nature of sub-objects becomes apparent when reviewing the state of module-heavy configurations, where resource identifiers get very long - e.g. `module.vpc[0].module.default_security_group[0].aws_vpc_security_group_egress_rule.egress_rule[0].id`.*

## Part 1: Understanding `for`

Terraform uses the keyword `for` in multiple contexts.
Its most popular usage is the `for_each` meta-argument, which you might know as an alternative to `count` or as part of a `dynamic` block.
This usage, where we transform collections using `for`, should not be confused with `for_each`; despite their similar name, they are *very* distant relatives.

In conventional programming, `for` defines loops that iteratively perform tasks.
HCL doesn't really perform tasks, though. In Terraform, `for` is more analogous to a [template directive](https://developer.hashicorp.com/terraform/language/expressions/strings#directives) or some other Herculean expansion of string interpolation.

In Terraform, `for` appears within collections. A `[for statement in square braces]` is a one-dimensional collection and a `{for statement in curly braces}` is a two-dimensional collection:

```text
[ for iterator in collection : output ]
# iterator: reference to the current item, pick any name you want
# collection: typically a tuple or list, but two-dimensional complex objects are allowed
# output: logic to perform on the item

{ for key, value in collection : output-key => output-value }
# key, value: references for each item in two-dimensional collections
# output-key => output-value: transformation creating key-value pairs
## The => operator is always used to split dynamic keys and values in "curly-brace fors"
```

We usually use for statements to uniformly transform a collection of zero to many variables.
For instance, given:

```hcl
var.companies = ["facebook", "apple", "pied piper"]
```

you can transform it as:

```hcl
[ for company in var.companies : "New ${title(company)}" ]
```

This results in:

```hcl
["New Facebook", "New Apple", "New Pied Piper"]
```

You can also transform a list of **strings** into a list of **objects**:

```hcl
[ for company in var.companies : {
  company        = company
  better_company = "New ${title(company)}"
} ]
```

Outputting:

```hcl
[
  { company = "facebook", better_company = "New Facebook" },
  { company = "apple", better_company = "New Apple" },
  { company = "pied piper", better_company = "New Pied Piper" }
]
```

## Part 2: Nested `for`

Nested `for` statements help consolidate complex data structures, such as lists of objects containing lists.

Let's start with a high-level example to illustrate the concept.

{{< alert "code" >}}
You should use comments to explain your reasoning when you are doing something unusual, to clarify relationships between resources in very complex files, or to facilitate automation tools such as doc generators. You should not add comments all over the place to explain basic language syntax.

I am intentionally adding *way* more comments to this block than I normally would to improve the visibility and accessibility of this blog post to authors of many experience levels; I do not condone commenting active code like this unless you get paid per line.
{{< /alert >}}

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
```

The output is a structured, nested tuple.
```hcl
[
  [
    # Fields like color, name, and size omitted here for brevity.

    { description = "This small, red strawberry tastes sweet." },
    { description = "This big, red apple tastes sweet." }
  ],
  [
    { description = "This small, green grape tastes tart." },
    { description = "This big, green watermelon tastes tart." } # TODO: Verify sweetness of watermelons.
  ]
]
```

Although we're working with nested **collections**, these aren't nested **objects**, enabling further uniform operations such as using Terraform's built-in `flatten` function.

We'll explore practical examples and the utility of `flatten` in the next post. Until then, may the `for`s be with you.

---
