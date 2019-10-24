from conda_press import main

def test_main(monkeypatch):
    # Sanity test for main to see if empty options are being handled
    monkeypatch.setattr(main, "run_convert_wheel", lambda x: None)
    main.main()
