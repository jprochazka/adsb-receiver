from flask import Flask, render_template
from backend.routes.blog import blog
from backend.routes.flights import flights
from backend.routes.links import links

app = Flask(__name__)
app.register_blueprint(blog)
app.register_blueprint(flights)
app.register_blueprint(links)

# /API/DOCS

@app.route('/api/docs')
def get_docs():
    print('sending docs')
    return render_template('swaggerui.html')