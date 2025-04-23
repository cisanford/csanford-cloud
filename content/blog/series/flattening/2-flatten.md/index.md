---
date: '2025-03-16'
draft: true
series: ["HCL Nested Fors"]
series_order: 2
slug: flatten
tags: ["terraform", "data-structures", "iac"]
title: 'Part 2: When does flattening make sense?'
summary: The "how" and "why" of the flatten command in all its glory.
weight: 2
---

## flatten 101

The focus of this article is to drill into *practical* usage of `flatten`. Before we get started, let's recap the *theoretical* definition of that function:

---

{{< lead >}}
`flatten` *takes a list and replaces any elements that are lists with a flattened sequence of the list contents.*
{{< /lead >}}

{{< button href="https://developer.hashicorp.com/terraform/language/functions/flatten" target="_blank"  >}}
Hashicorp Documentation
{{< /button >}}

---

As we saw in part 1, Terraform developers often need to receive nested input to dynamically create zero-to-many resources (or sub-resources) - *specifically*, using

- the `for_each` meta-argument, or
- a `dynamic` block

Because iterators in Terraform are not logical operators, they aren't great with "multi-dimensional" object input. For example, if I need to make several subnets, I need to provide a list of subnets - not one list of public subnets and a list of private subnets.

```hcl
locals {
# OK
subnets = [{name = string, cidr = string}, {name = string, cidr = string}, {name = string, cidr = string}]
# Not OK
bad_subnets = [
  [{ name = string, cidr = string }, { name = string, cidr = string }],
  [{ name = string, cidr = string }]
]
}
```

{{< alert >}}
When using the `for_each` [meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each), remember that each instance of a resource/data source/module/etc requires a **unique** key value in `string` format. `for_each` collections are hash tables, so that key serves as the item's **index**. This is why `for_each` requires either a list of known-before-apply strings, or a list of key-value objects (i.e. `key => value` expressions.)

When flattening nested lists, make sure that each object has a `string` attribute to serve as a unique identifier that is friendly enough to easily identify in the state file later. For most resources, the `Name` is sufficient, but your situation may vary.
{{< /alert >}}

### TL;DR

`flatten` can be used in a few contexts, but it's almost always seen in the wild to **normalize nested lists** for use in a `for_each` statement.

With this in mind, let's go back to our fruit salad.

---

## Fruit Kebabs

We'll reference some content from the last post, so to save you the trouble of tabbing back and forth here's the relevant part.

### Recap

In [part 1](../1-for), we proposed a scenario where we needed to action a group of fruits as described in the following YAML snippet:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/for-2/content/blog/series/flattening/assets/fruit-salad.yaml" type="yaml" >}}

Using nested `for` statements, we were able to convert that YAML into nested tuples:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/for-2/content/blog/series/flattening/assets/fruit-salad.hcl" type="hcl" startLine="39" endLine="76" >}}

### Moving on

Let's assume I need to make four resources called `fruit_chunk`. The `fruit_chunk` resource (defined by the fictitious `tastycorp/fruit` provider) has the following arguments:

| Name        | Description                               | Type   | Default              |
|-------------|-------------------------------------------|--------|----------------------|
| name        | Common name of the fruit                  | string | *required*           |
| color       | Rough color of the fruit's exterior       | string | *required*           |
| flavor      | Primary flavor profile of the fruit       | string | *required*           |
| large       | Whether the fruit is big                  | bool   | *required*           |
| description | Friendly sentence talking about the fruit | string | "Hey, look at that!" |

To create zero-to-many fruit chunks for my kebab, I can use a `for_each` block that looks like this:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/for-2/content/blog/series/flattening/assets/fruit-kebab.hcl" type="hcl" startLine="5" endLine="16" >}}

This for_each argument obviously requires a **list of objects**.

I wish I could say this grand reveal is complicated and flashy, but it's not:

{{< codeimporter url="https://raw.githubusercontent.com/cisanford/csanford-cloud/for-2/content/blog/series/flattening/assets/fruit-kebab.hcl" type="hcl" startLine="1" endLine="3" >}}

That simple flatten statement will convert `[[obj, obj], [obj, obj]]` to `[obj, obj, obj, obj]` in one go. The latter is suitable for a `for_each` meta-argument.

---

### A last note on for_each

Note how we structured for_each:
`for_each = { for fruit in local.fruits: fruit.name => fruit }`
- The opening `{` indicates that we are providing a key/value input
- `for fruit in local.fruits` defines the name of the **iterator** - this is only what comes after the `:` in the for statement and is not necessarily consumed in the resource
- `fruit.name => fruit` indicates that the **key** is the `name` **attribute** of each `fruit` (an object within the collection `local.fruits`), and the **value** (referenced as `each.value` in the object) is the **entire fruit object**, including the `name` attribute

---

So just like that, we're done with our fruit salad example, and it's time to move on to some real world examples!
