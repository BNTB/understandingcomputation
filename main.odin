package main

import "core:fmt"

ExprKind :: enum
{
    NUMBER,
    ADD,
    MULTIPLY,
    BOOLEAN,
    LESS_THAN,
    VARIABLE,
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
    name: string,
	is_reducible: bool,
}

make_number :: proc (val: int) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .NUMBER
    expr.Data.Number.value = val
	expr.is_reducible = false

    return expr
}

make_add :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .ADD
    expr.Data.BinOp.c = '+'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right
	expr.is_reducible = true

    return expr
}

make_multiply :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .MULTIPLY
    expr.Data.BinOp.c = '*'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right
	expr.is_reducible = true

    return expr
}

make_boolean :: proc (value: bool) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .BOOLEAN
    expr.Data.Number.value = (int)(value)
	expr.is_reducible = false

    return expr
}

make_less_than :: proc (left, right: ^Expr) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .LESS_THAN
    expr.Data.BinOp.c = '<'
    expr.Data.BinOp.left = left
    expr.Data.BinOp.right = right
	expr.is_reducible = true

    return expr
}

make_variable :: proc (name: string) -> ^Expr
{
    expr := new(Expr)
    expr.kind = .VARIABLE
    expr.name = name
	expr.is_reducible = true

    return expr
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
            fmt.printf("%s ", expr.name)
    }
}

reduce_expr :: proc (expr: ^Expr, env: ^map[string]int) -> ^Expr
{
    if expr != nil
    {
        #partial switch expr.kind
        {
            case .ADD:
                if expr.Data.BinOp.left.is_reducible do return make_add(reduce_expr(expr.Data.BinOp.left, env), expr.Data.BinOp.right)
                else if expr.Data.BinOp.right.is_reducible do return make_add(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, env))
                else do return make_number(expr.Data.BinOp.left.Data.Number.value + expr.Data.BinOp.right.Data.Number.value)
            case .MULTIPLY:
                if expr.Data.BinOp.left.is_reducible do return make_multiply(reduce_expr(expr.Data.BinOp.left, env), expr.Data.BinOp.right)
                else if expr.Data.BinOp.right.is_reducible do return make_multiply(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, env))
                else do return make_number(expr.Data.BinOp.left.Data.Number.value * expr.Data.BinOp.right.Data.Number.value)
            case .LESS_THAN:
                if expr.Data.BinOp.left.is_reducible do return make_less_than(reduce_expr(expr.Data.BinOp.left, env), expr.Data.BinOp.right)
                else if expr.Data.BinOp.right.is_reducible do return make_less_than(expr.Data.BinOp.left, reduce_expr(expr.Data.BinOp.right, env))
                else do return make_number(1 if expr.Data.BinOp.left < expr.Data.BinOp.right else 0) // book uses make boolean but whatever I'm already defining bools as ints
            case .VARIABLE:
                return make_number(env[expr.name])
        }
    }
    return nil
}

Machine :: struct
{
    statement: Statement,
    env: map[string]int
}

make_machine :: proc (statement: ^Statement, env: ^map[string]int) -> ^Machine
{
    machine := new(Machine)
    machine.statement = statement^
    machine.env = env^

    return machine
}

step :: proc (machine: ^Machine)
{
    ptr_to_machine_stmnt, ptr_to_machine_env := reduce_stmnt(&machine.statement, &machine.env)
	machine.statement = ptr_to_machine_stmnt^
	machine.env = ptr_to_machine_env^
}

run :: proc (machine: ^Machine)
{
    for machine.statement.is_reducible
    {
        print_stmnt(&machine.statement)
		print_env(&machine.env)
		fmt.println()
        step(machine)
    }
	print_stmnt(&machine.statement)
	print_env(&machine.env)
	fmt.println()
}

StatementKind :: enum 
{
	DO_NOTHING,
	ASSIGN,
	IF,
	SEQUENCE,
	WHILE
}

Statement :: struct 
{
	kind: StatementKind,
	Data: struct #raw_union
	{
		BinOp: struct 
		{
			var: ^Expr,
			op: u8,
			expr: ^Expr
		}
	},
	If: struct 
	{
		condition: ^Expr, 
		consequence: ^Statement,
		alternative: ^Statement,
	},
	Sequence: struct 
	{
		first: ^Statement,
		second: ^Statement
	},
	While: struct 
	{
		condition: ^Expr,
		body: ^Statement
	},
	is_reducible: bool,
}

make_assign :: proc (name: string, expr: ^Expr) -> ^Statement
{
	stmnt := new(Statement)
	stmnt.kind = .ASSIGN
	stmnt.is_reducible = true
	stmnt.Data.BinOp.var = new(Expr)
	stmnt.Data.BinOp.var.kind = .VARIABLE
	stmnt.Data.BinOp.var.name = name 
	stmnt.Data.BinOp.op = '='
	stmnt.Data.BinOp.expr = expr
	
	return stmnt
}

make_DoNothing :: proc () -> ^Statement
{
	stmnt := new(Statement)
	stmnt.kind = .DO_NOTHING
	stmnt.is_reducible = false
	
	return stmnt
}

make_if :: proc (condition: ^Expr, consequence: ^Statement, alternative: ^Statement) -> ^Statement
{
	if_stmnt := new(Statement)
	if_stmnt.kind = .IF
	if_stmnt.If.condition = condition
	if_stmnt.If.consequence = consequence
	if_stmnt.If.alternative = alternative
	if_stmnt.is_reducible = true
	
	return if_stmnt
}

make_sequence :: proc (first: ^Statement, second: ^Statement) -> ^Statement
{
	sequence_stmnt := new(Statement)
	sequence_stmnt.kind = .SEQUENCE
	sequence_stmnt.Sequence.first = first
	sequence_stmnt.Sequence.second = second
	sequence_stmnt.is_reducible = true
	
	return sequence_stmnt
}

make_while :: proc (cond: ^Expr, body: ^Statement) -> ^Statement
{
	while_stmnt := new(Statement)
	while_stmnt.kind = .WHILE
	while_stmnt.is_reducible = true
	while_stmnt.While.condition = cond
	while_stmnt.While.body = body
	
	return while_stmnt
}

reduce_stmnt :: proc (stmnt: ^Statement, env: ^map[string]int) -> (^Statement, ^map[string]int)
{
	switch stmnt.kind
	{
		case .DO_NOTHING:
			return stmnt, env
		case .ASSIGN:
			if stmnt.Data.BinOp.expr.is_reducible do return make_assign(stmnt.Data.BinOp.var.name, reduce_expr(stmnt.Data.BinOp.expr, env)), env
			else
			{
				env[stmnt.Data.BinOp.var.name] = stmnt.Data.BinOp.expr.Data.Number.value
				return make_DoNothing(), env
			}
		case .IF:
			if stmnt.If.condition.is_reducible do return make_if(reduce_expr(stmnt.If.condition, env), stmnt.If.consequence, stmnt.If.alternative), env
			else
			{
				if stmnt.If.condition.Data.Number.value == 1 do return stmnt.If.consequence, env
				else if stmnt.If.condition.Data.Number.value == 0 do return stmnt.If.alternative, env
			}
		case .SEQUENCE:
			if stmnt.Sequence.first.kind == .DO_NOTHING do return stmnt.Sequence.second, env 
			else if stmnt.Sequence.first.kind != .DO_NOTHING
			{
				reduced_first, reduced_env := reduce_stmnt(stmnt.Sequence.first, env)
				return make_sequence(reduced_first, stmnt.Sequence.second), reduced_env
			}
		case .WHILE:
			return make_if(stmnt.While.condition, make_sequence(stmnt.While.body, make_while(stmnt.While.condition, stmnt.While.body)), make_DoNothing()), env // ci avevo visto giusto passare stmnt come pointer 
	}
	return nil, nil
}

print_stmnt :: proc (stmnt: ^Statement) 
{
	switch stmnt.kind 
	{
		case .DO_NOTHING:
			fmt.printf("do-nothing ")
		case .ASSIGN:
			fmt.printf("%s %c ", stmnt.Data.BinOp.var.name, stmnt.Data.BinOp.op)
			print_expr(stmnt.Data.BinOp.expr)
		case .IF:
			fmt.printf("if ")
			print_expr(stmnt.If.condition)
			print_stmnt(stmnt.If.consequence)
			fmt.printf("else ")
			print_stmnt(stmnt.If.alternative)
		case .SEQUENCE:
			print_stmnt(stmnt.Sequence.first)
			fmt.printf("; ")
			print_stmnt(stmnt.Sequence.second)
		case .WHILE:
			fmt.printf("while ")
			print_expr(stmnt.While.condition)
			print_stmnt(stmnt.While.body)
	}
}

print_env :: proc (env: ^map[string]int) 
{
	for key in env 
	{
		fmt.printf("%s => <<%d>> ", key, env[key])
	}
}

DoNothing_equality :: proc (stmnt, other_stmnt: ^Statement) -> bool
{
	if stmnt.kind == .DO_NOTHING && other_stmnt.kind == .DO_NOTHING do return true
	return false
}

main :: proc()
{
    env := make(map[string]int)
	env["x"] = 1
    statement := make_while(make_less_than(make_variable("x"), make_number(5)), make_assign("x", make_multiply(make_variable("x"), make_number(3))))
    machine := make_machine(statement, &env)
    run(machine)
}
