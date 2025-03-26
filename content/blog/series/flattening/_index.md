---
title: Flattening is Happening
summary: Let's break down Terraform's [for] in ways that actually make sense. A 3-part series.
tags: ['series', 'terraform']

cascade:
  showDate: false
  showAuthor: false
  invertPagination: true

params:
  cardView: true
  groupByYear: false

weight: 2
---

## Where `for` art thou romeo

![Scrolling code thumbnail](./feature-thumb.gif)

In this series, I'll break down a more obvious version of the sample usage for `flatten` included in the [HCL documentation](https://developer.hashicorp.com/terraform/language/functions/flatten#flattening-nested-structures-for-for_each), expanding each concept into chunks you can understand without a ton of trial and error.

We'll break this up into three parts:
1) How `for` works in Terraform
2) What `flatten` is all about
3) Some real life use cases: AWS security group rules, and GCP IAM role membership

Now that we have a plan, let's get started!

---

### Documentation

- [for](https://developer.hashicorp.com/terraform/language/expressions/for)
- [flatten](https://developer.hashicorp.com/terraform/language/functions/flatten)
- [security group rules](https://aws.amazon.com/blogs/aws/easily-manage-security-group-rules-with-the-new-security-group-rule-id/)
