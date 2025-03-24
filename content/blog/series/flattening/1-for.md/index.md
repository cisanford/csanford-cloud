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

Using `for` to handle dynamic collections is a critical tool for any Terraform developer's arsenal, and handling **nested** `for` collections is a technique that's as powerful as it is flashy.
Unfortunately, Terraform's use of `for` is notoriously counterintuitive:
- It defines a variable; it does not manipulate one.
- Its behavior and usage vary on context (e.g., `[square braces]` or `{curly braces}`.)
- HCL's version of `for` is not technically a loop.

{{< lead >}} `for` is not a loop. Neat! {{< /lead >}}
<!-- This carousel iterates through screenshots of ChatGPT explaining the term 'loop' and HCL's 'for' to prove that for is not a loop. -->
{{< carousel images="dictionary/*" aspectRatio="16-9" interval="2500" >}}

In this post, I want to spend some time unpacking how `for` statements are structured in HCL, and provide some more obvious visualization than you might have seen before into their usage.

## Prerequisites

Let's start out by clarifying some vocabulary around collections in Terraform.

Collections can generally be classified into either one-dimensional (A collection of values) or two-dimensional (a collection of both keys and values). We'll compare and contrast them in the table below.

{{< alert >}}
Items in some collections may themselves be collections. Nesting raises the complexity level.
{{< /alert >}}

| Attribute  | 1-dimensional          | 2-dimensional    |
| :--------  |  :------------------:  |   -------------: |
| Examples   | `list`, `set`, `tuple` | `map`, `object`  |
| Appearance | [ square brackets ]    | { curly braces } |
| Structure  | Values only            | Key = Value      |
| Index      | count supported        | key `string`     |

### Picking a collection type
`for` generally defines either a 1D `tuple` or a 2D `object`.

#### Tuples
- A list requires all elements to be the same data type, and is ordered.
- A set requires all elements to be unique, and is unordered.
- A **tuple** is ordered, but can hold different data types simultaneously.

If Terraform can't tell in advance what's going to go into a one-dimensional collection, it uses a `tuple` just to be safe. In the context of technical writing or error output, you'll see `tuple` used in dynamic contexts (like `for`), but if you're having a conversation in the office or Slack it's usually OK to use the term "list" interchangeably.

#### Objects
- A **map** requires all values to be the same type. (You usually use this for key/value pairs of strings, like tags.) Maps also support [lookup](https://developer.hashicorp.com/terraform/language/functions/lookup).
- An object can have values of any type. Its keys need to be strings, since they are attribute names. (For example, a `data.aws_s3_bucket` is an object, and one of its key/value pairs is `id = bucket-name`.)

Because we can define an arbitrary structure/schema in our `for` expression, a two-dimensional `for` usually spits out an object.

### Another note on typing

Terraform uses weak typing, so if you pass a tuple where a list is expected, Terraform will convert it automatically. Similarly, if you try to use an `object` as a `map`, Terraform will do the conversion on the spot as long as all the values are the same type. This means you could use a `{ for expression }` to dynamically tag AWS resources, for example.

In summary:

- Values enclosed in `[square brackets]` are typically one-dimensional collections (tuples).
- Values enclosed in `{curly braces}` are typically two-dimensional collections (objects).

We want to keep this distinction in mind when working with the `for` keyword, as it appears **within** a collection rather than as a standalone expression.

> *The sinister nature of sub-objects becomes apparent when reviewing the state of module-heavy configurations, where resource identifiers get very long - e.g. `module.vpc[0].module.default_security_group[0].aws_vpc_security_group_egress_rule.egress_rule[0].id`.*

## Understanding `for`

Terraform uses the keyword `for` in multiple contexts.
Its most popular usage is the `for_each` meta-argument, which you might know as an alternative to `count` or as part of a `dynamic` block.
This usage, where we transform collections using `for`, should not be confused with `for_each`; despite their similar name, they are *very* distant relatives.

In conventional programming, `for` defines loops that iteratively perform tasks.
HCL doesn't perform actions or tasks directly. Instead, for is like a [template directive](https://developer.hashicorp.com/terraform/language/expressions/strings#directives) used to transform and interpolate strings or collections."

`for` appears **within** collections. A `[for statement in square braces]` is a one-dimensional collection and a `{for statement in curly braces}` is a two-dimensional collection:

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

### Fruit Salad

A very common situation for nested `for` expressions is when you need to read a complex JSON or YAML file into a variable, and break it into pieces you can actually use.

Suppose I am writing a module that needs to consume the following variable:
```hcl
variable "fruit_salad" {
  description = "A list of desirable fruits, sorted by their skin color."
  type = list(object({
    color = string
    flavor = string
    fruits = list(object({
      name = string
      size = string
    }))
  }))
}
```

You can greatly improve your user experience by ingesting this variable in a YAML manifest. For example:
```yaml
colors:
  - color: red
    flavor: sweet
    fruits:
      - name: strawberry
        size: small
      - name: apple
        size: big
  - color: green
    flavor: tart
    fruits:
      - name: grape
        size: small
      - name: watermelon
        size: big
```

The following HCL snippet will demonstrate how to iterate through this YAML using `for`.

{{< alert "code" >}}
You should use comments to explain your reasoning when you are doing something unusual, to clarify relationships between resources in very complex files, or to facilitate automation tools such as doc generators. You should not add comments all over the place to explain basic language syntax.

I am intentionally adding *way* more comments to this block than I normally would to improve the visibility and accessibility of this blog post to authors of many experience levels; I do not condone commenting active code like this unless you get paid per line.
{{< /alert >}}

```hcl
locals {
  # Import the payload:
  colors = yamldecode(var.manifest_path) # Path to the YAML above

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

We still have a reasonably complicated data set (nested collections), but it's *much* tidier than where we started (nested objects). We've transformed elements from multiple scopes, and now have entries for each of the most specific entries in the manifest.

Using nested for expressions, we’ve transformed a complex, multi-layered YAML input into a structured, manageable dataset. This (surprisingly!) flexible method allows you to modularize your code, simplify input validation, and ensure consistency across configurations.

The next logical step is **consolidation**: using Terraform's built-in `flatten` function to convert these nested structures into a flat, predictable collection that we can iterate through using meta-arguments like `for_each`.

`flatten`, famously, expects a `list` of `lists`. Because everything in our output is the same type (down to the object schema!), our `tuples` are eligible for promotion to `lists`, and we can consolidate them.

We'll walk through how (and why) I use flatten, and how it can further simplify your workloads, in the next post.

---
