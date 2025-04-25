package main

import "core:fmt"

ExprKind :: enum
{
    NUMBER,
    ADD,
    MULTIPLY,
    BOOLEAN,
    LESS_THAN,
    VARIABLE
}

Expr :: struct
{
    kind: ExprKind,
    Data: struct #raw_union
    {
        Number: struct
        {
            value: int
        },
        BinOp: struct
        {
            left, right: ^Expr,
            c: u8
        }
    },
    name: string
}

make_number :: proc (val: int) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .NUMBER
    expr.Data.Number.value = val

    return expr
}

make_add :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .ADD
    expr.Data.BinOp.c = '+'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right

    return expr
}

make_multiply :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .MULTIPLY
    expr.Data.BinOp.c = '*'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right

    return expr
}

make_boolean :: proc (value: bool) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .BOOLEAN
    expr.Data.Number.value = (int)(value)

    return expr
}

make_less_than :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .LESS_THAN
    expr.Data.BinOp.c = '<'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right

    return expr
}

make_variable :: proc (name: string, val: int) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .VARIABLE
    expr.name = name
    expr.Data.Number.value = val

    return expr
}

is_reducible :: proc (expr: ^Expr) -> bool
{
    if expr == nil do return false

    switch expr.kind
    {
        case .NUMBER    : return false
        case .ADD       : return true
        case .MULTIPLY  : return true
        case .BOOLEAN   : return false
        case .LESS_THAN : return true
        case .VARIABLE  : return true
    }

    return false
}

print_expr :: proc (expr: ^Expr)
{
    if expr == nil
    {
        fmt.printf("")
        return
    }

    switch expr.kind
    {
        case .NUMBER:
            fmt.printf("%d ", expr.Data.Number.value)
            return
        case .ADD:
            print_expr(expr.Data.BinOp.left)
            fmt.printf("%c ", expr.Data.BinOp.c)
            print_expr(expr.Data.BinOp.right)
        case .MULTIPLY:
            print_expr(expr.Data.BinOp.left)
            fmt.printf("%c ", expr.Data.BinOp.c)
            print_expr(expr.Data.BinOp.right)
        case .BOOLEAN:
            fmt.printf("%s ", string("TRUE") if expr.Data.Number.value == 1 else string("FALSE"))
        case .LESS_THAN:
            print_expr(expr.Data.BinOp.left)
            fmt.printf("%c ", expr.Data.BinOp.c)
            print_expr(expr.Data.BinOp.right)
        case .VARIABLE:
            fmt.printf("%")
    }
}

// la riduce tutta...
// reduce :: proc (expr: ^Expr) -> ^Expr
// {
//     if expr != nil
//     {
//         if expr.kind == .NUMBER do return expr
//         else
//         {
//             #partial switch expr.kind
//             {
//                 case .ADD:
//                     left := reduce(expr.Data.BinOp.left)
//                     right := reduce(expr.Data.BinOp.right)
//                     return make_number(left.Data.Number.value + right.Data.Number.value)
//
//                 case .MULTIPLY:
//                     left := reduce(expr.Data.BinOp.left)
//                     right := reduce(expr.Data.BinOp.right)
//                     return make_number(left.Data.Number.value * right.Data.Number.value)
//             }
//         }
//     }
//     return nil
// }

reduce_expr :: proc (expr: ^Expr, env: ^map[string]int) -> ^Expr
{
    if expr != nil
    {
        #partial switch expr.kind
        {
            case .ADD:
                if is_reducible(expr.Data.BinOp.left) do return make_add(reduce_expr(expr.Data.BinOp.left, nil), expr.Data.BinOp.right)
                else if is_reducible(expr.Data.BinOp.right) do return make_add(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, nil))
                else do return make_number(expr.Data.BinOp.left.Data.Number.value + expr.Data.BinOp.right.Data.Number.value)
            case .MULTIPLY:
                if is_reducible(expr.Data.BinOp.left) do return make_multiply(reduce_expr(expr.Data.BinOp.left, nil), expr.Data.BinOp.right)
                else if is_reducible(expr.Data.BinOp.right) do return make_multiply(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, nil))
                else do return make_number(expr.Data.BinOp.left.Data.Number.value * expr.Data.BinOp.right.Data.Number.value)
            case .LESS_THAN:
                if is_reducible(expr.Data.BinOp.left) do return make_less_than(reduce_expr(expr.Data.BinOp.left, nil), expr.Data.BinOp.right)
                else if is_reducible(expr.Data.BinOp.right) do return make_less_than(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, nil))
                else do return make_number(1 if expr.Data.BinOp.left < expr.Data.BinOp.right else 0) // book uses make boolean but whatever I'm already defining bools as ints
        }
    }
    return nil
}

Machine :: struct
{
    expr: Expr
}

make_machine :: proc (expression: ^Expr) -> ^Machine
{
    machine := new(Machine)
    machine.expr = expression^
    return machine
}

step :: proc (machine: ^Machine)
{
    machine.expr = reduce_expr(&machine.expr, nil)^
}

run :: proc (machine: ^Machine)
{
    for is_reducible(&machine.expr)
    {
        print_expr(&machine.expr)
        step(machine)
    }
    print_expr(&machine.expr)
}

main :: proc()
{
    expr := make_multiply(make_add(make_number(1), make_number(2)), make_add(make_number(3), make_number(4)))
    print_expr(expr)

    newexpr : ^Expr

    fmt.println()

    if is_reducible(expr) do newexpr = reduce_expr(expr, nil)
    print_expr(newexpr)
}
