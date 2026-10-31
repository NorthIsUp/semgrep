# ruleid: template-string
t"Hello {name}"
# ruleid: template-string
T'Hello {user}'
# ruleid: template-string
rt"Hello {name}"
# ok: template-string
f"Hello {name}"
# ok: template-string
"Hello {name}"

# ruleid: template-expression
t"{source()}"
# ruleid: template-expression
t"{value:{source()}}"

# ok: plain-string
consume(t"hello")
# ok: plain-string
consume(t"{'hello'}")
# ruleid: plain-string
consume(f"hello")
# ruleid: plain-string
consume("hello")

template = t"hello"
# ok: plain-string
consume(template)
joined = t"hel" t"lo"
# ok: plain-string
consume(joined)

# ok: string-comparison
compare(t"hello")
# ok: string-comparison
compare(template)
# ok: string-comparison
compare(joined)
# ruleid: string-comparison
compare(f"hello")
# ruleid: string-comparison
compare("hello")

# ruleid: cooked-template
newline(t"\n{value}")
# ruleid: cooked-template
newline(t"""
{value}""")
# ok: cooked-template
newline(rt"\n{value}")
# ok: cooked-template
newline(Tr"\n{value}")

# ruleid: any-template
show(t"")
# ruleid: any-template
show(t"Hello {name}, {value}")
# ok: any-template
show(f"Hello {name}")

# ruleid: template-expression
tainted_template = t"{source()}"
# ruleid: template-taint
sink(tainted_template)
# ok: template-taint
sink(t"clean")
