---
date: '2025-04-21'
draft: false
series: ["HCL Nested Fors"]
series_order: 2
slug: flatten
tags: ["terraform", "data-structures", "iac"]
title: 'Part 2: Time to get flat'
summary: The "how" and "why" of the flatten command in all its glory.
weight: 2
---

## flatten 101

This article drills into the *practical* usage of Terraform's `flatten` function. Before we start, let's quickly recap its *theoretical* definition:

---

{{< lead >}}
`flatten` *takes a list and replaces any elements that are lists with a flattened sequence of the list contents.*
{{< /lead >}}

{{< button href="https://developer.hashicorp.com/terraform/language/functions/flatten" target="_blank"  >}}
Hashicorp Documentation
{{< /button >}}

---

As we saw in part 1, Terraform developers often need to receive nested input to dynamically create zero-to-many resources (or sub-resources), *specifically* by using either

- the `for_each` meta-argument, or
- a `dynamic` block.

Because iterators in Terraform are not logical operators, they aren't great at handling "multi-dimensional" nested input directly. For instance, if you need multiple subnets, you should provide a single flat list rather than separate nested lists for public and private subnets:

```hcl
locals {
  # Good
  subnets = [
    { name = string, cidr = string },
    { name = string, cidr = string },
    { name = string, cidr = string }
  ]

  # Not good
  bad_subnets = [
    [{ name = string, cidr = string }, { name = string, cidr = string }],
    [{ name = string, cidr = string }]
  ]
}
```

{{< alert >}}
When using the `for_each` [meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each), each instance of a [resource | data source | module | etc] requires a **unique** 'key' in `string` format. `for_each` collections behave like hash tables, so that key acts as the item's **index**. 
- This is why `for_each` requires either a list of known-before-apply strings, or a list of key-value objects (i.e. `key => value` expressions.)

When composing lists of "two-dimensional" objects, ensure each object includes a unique `string` attribute suitable for identifying resources easily in the Terraform state file. Usually, the object's `name` attribute suffices, but this might differ based on your use case.
{{< /alert >}}

### TL;DR

`flatten` can be applied in several contexts, but it's most commonly (by a lot) used to *normalize nested lists* for use with `for_each`.

With this in mind, let's go back to our fruit salad.

---

## Fruit Kebabs

We'll reference some content from the last post, so to save you the trouble of tabbing back and forth here's the relevant part.

### Quick Recap

In [part 1](../nested-for), we introduced a scenario where we needed to action a group of fruits as described in the following YAML snippet:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/fix-dns/content/blog/series/flattening/assets/fruit-salad.yaml" type="yaml" >}}

Using nested `for` expressions, we converted that YAML into nested tuples:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/fix-dns/content/blog/series/flattening/assets/fruit-salad.hcl" type="hcl" startLine="39" endLine="76" >}}

### Moving on

Suppose we want to make multiple resources (in this case, four of them) called `fruit_chunk`. The `fruit_chunk` resource (from our fictitious `tastycorp/fruit` provider) has the following arguments:

| Name        | Description                               | Type   | Default              |
|-------------|-------------------------------------------|--------|----------------------|
| name        | Common name of the fruit                  | string | *required*           |
| color       | Rough color of the fruit's exterior       | string | *required*           |
| flavor      | Primary flavor profile of the fruit       | string | *required*           |
| large       | Whether the fruit is big                  | bool   | *required*           |
| description | Friendly sentence talking about the fruit | string | "Hey, look at that!" |

To create zero-to-many fruit chunks for a kebab, we can use a `for_each` block:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/fix-dns/content/blog/series/flattening/assets/fruit-kebab.hcl" type="hcl" startLine="5" endLine="16" >}}

Eagle-eyed observers will note that this for_each argument requires a **list of objects**.

I wish I could say this grand reveal is complicated and flashy, but it's not:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/fix-dns/content/blog/series/flattening/assets/fruit-kebab.hcl" type="hcl" startLine="1" endLine="3" >}}

That simple flatten statement will convert a nested list structure (`[[obj, obj], [obj, obj]]`) to a flat one (`[obj, obj, obj, obj]`) in one go. The **flattened** version is suitable for a `for_each` meta-argument.

---

### A last note on for_each

Let's review the for_each structure:
`for_each = { for fruit in local.fruits: fruit.name => fruit }`
- The opening `{` indicates a map of key-value pairs.
- `for fruit in local.fruits` defines the  iterator. This iterator is scoped to the expression: it is mentioned after the `:` in the for statement, and might not not be consumed in the resource at all.
- `fruit.name => fruit` specifies that:
  - The **key** is the `name` **attribute** of each `fruit` (an object within the collection `local.fruits`)
  - The **value** (accessible as `each.value` in the resource) is the **entire fruit object**, including the `name`.

---

With that, we're done with our fruit salad example! Now it's time to explore some real-world scenarios.
