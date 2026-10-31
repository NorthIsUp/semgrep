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
