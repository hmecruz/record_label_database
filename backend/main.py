from backend import create_app

app = create_app()

if __name__ == '__main__':
    app.run(
        host=app.config['HOST'],
        port=app.config['PORT'],
        debug=True,
    )
    
# run: python -m backend.main at the root of the project